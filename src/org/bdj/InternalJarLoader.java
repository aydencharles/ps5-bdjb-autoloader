package org.bdj;

import java.io.*;
import java.net.*;
import java.lang.reflect.Method;
import java.util.jar.JarFile;
import java.util.jar.Manifest;
import java.util.jar.Attributes;
import org.bdj.api.KernelAPI;

public class InternalJarLoader implements Runnable {
    
    public InternalJarLoader() {
        cleanupOldTempFiles();
    }
    
    public void run() {
        try {
            File poopsJar = new File("/disc/poops.jar");
            if (poopsJar.exists()) {
                Status.setProgress(30, "Executing poops.jar...");
                runJar(poopsJar);
            } else {
                Status.warning("poops.jar not found at /disc/poops.jar");
            }
            

            File autoloaderJar = new File("/disc/autoloader.jar");
            if (autoloaderJar.exists()) {
                Status.setProgress(80, "Starting Autoloader...");
                runJar(autoloaderJar);
            } else {
                Status.warning("autoloader.jar not found at /disc/autoloader.jar");
            }
        } catch (IOException e) {
            Status.printStackTrace("JarLoader error", e);
        } catch (Exception e) {
            if (e.getCause() != null && "ABORT".equals(e.getCause().getMessage())) {
                // poops.jar aborted intentionally (e.g. already jailbroken), silently skip autoloader
            } else {
                Status.printStackTrace("JarLoader error", e);
            }
        }
    }

    private static void runJar(File jarFile) throws Exception {
        // Copy JAR to temp directory to avoid disc permission issues
        File tempFile = File.createTempFile("loader", ".jar");
        tempFile.deleteOnExit();
        
        Status.info("Loading " + jarFile.getName() + "...");
        InputStream is = new FileInputStream(jarFile);
        OutputStream os = new FileOutputStream(tempFile);
        byte[] buf = new byte[8192];
        int len;
        while ((len = is.read(buf)) > 0) {
            os.write(buf, 0, len);
        }
        is.close();
        os.close();

        // Read the manifest to find the main class
        JarFile jar = new JarFile(tempFile);
        Manifest manifest = jar.getManifest();
        jar.close();
        
        if (manifest == null) {
            tempFile.delete();
            throw new Exception("No manifest found in JAR");
        }
        
        String mainClassName = manifest.getMainAttributes().getValue(Attributes.Name.MAIN_CLASS);
        if (mainClassName == null) {
            tempFile.delete();
            throw new Exception("No Main-Class specified in manifest");
        }
        
        final ClassLoader parentLoader = InternalJarLoader.class.getClassLoader();
        ClassLoader bypassRestrictionsLoader = new URLClassLoader(new URL[0], parentLoader) {
            protected Class loadClass(String name, boolean resolve) throws ClassNotFoundException {
                if (name.startsWith("java.") || name.startsWith("javax.") || name.startsWith("jdk.")) {
                    return findSystemClass(name);
                }
                return super.loadClass(name, resolve);
            }
        };
        
        URL jarUrl = tempFile.toURL();
        URLClassLoader classLoader = URLClassLoader.newInstance(new URL[]{jarUrl}, bypassRestrictionsLoader);
        
        Class mainClass = classLoader.loadClass(mainClassName);
        Method mainMethod = mainClass.getMethod("main", new Class[]{String[].class});
        
        ClassLoader oldLoader = Thread.currentThread().getContextClassLoader();
        try {
            Thread.currentThread().setContextClassLoader(classLoader);
            mainMethod.invoke(null, new Object[]{new String[0]});
        } finally {
            Thread.currentThread().setContextClassLoader(oldLoader);
            tempFile.delete();
        }
        
        Status.success(mainClassName + " execution completed");
    }

    private void cleanupOldTempFiles() {
        try {
            String tempDir = System.getProperty("java.io.tmpdir");
            File tempFolder = new File(tempDir);
            File[] files = tempFolder.listFiles();
            
            if (files != null) {
                int cleanedCount = 0;
                for (int i = 0; i < files.length; i++) {
                    File file = files[i];
                    if (file.getName().startsWith("received") && file.getName().endsWith(".jar")) {
                        if (file.delete()) {
                            cleanedCount++;
                        }
                    }
                }
                if (cleanedCount > 0) {
                    Status.info("Cleaned up " + cleanedCount + " old temp JAR files");
                }
            }
        } catch (Exception e) {
            Status.warning("Could not clean temp files: " + e.getMessage());
        }
    }
}