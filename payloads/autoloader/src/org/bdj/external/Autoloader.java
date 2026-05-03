package org.bdj.external;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.util.List;
import org.bdj.Status;
import org.bdj.api.*;

public class Autoloader {
    private static final String AUTOLOAD_DIR = "ps5_autoloader";
    private static final String AUTOLOAD_FILE = "autoload.txt";

    private static API api;
    private static long getpid;
    private static long getuid;
    private static long kill;
    private static long sceKernelCheckReachability;
    private static long open;
    private static long read;
    private static long close;
    private static long getdents;

    static {
        try {
            api = API.getInstance();
            getpid = api.dlsym(API.LIBKERNEL_MODULE_HANDLE, "getpid");
            getuid = api.dlsym(API.LIBKERNEL_MODULE_HANDLE, "getuid");
            kill = api.dlsym(API.LIBKERNEL_MODULE_HANDLE, "kill");
            sceKernelCheckReachability = api.dlsym(API.LIBKERNEL_MODULE_HANDLE, "sceKernelCheckReachability");
            open = api.dlsym(API.LIBKERNEL_MODULE_HANDLE, "open");
            read = api.dlsym(API.LIBKERNEL_MODULE_HANDLE, "read");
            close = api.dlsym(API.LIBKERNEL_MODULE_HANDLE, "close");
            getdents = api.dlsym(API.LIBKERNEL_MODULE_HANDLE, "getdents");
        } catch (Exception e) {
            Status.printStackTrace("Failed to initialize Autoloader native symbols", e);
        }
    }

    public static void main(String[] args) {
        Status.println("Autoloader starting...");
        
        try {
            int uid = (int) api.call(getuid);
            int pid = (int) api.call(getpid);
            Status.println("UID: " + uid + ", PID: " + pid);
        } catch (Throwable ignored) {}

        String configPath = findConfig();
        if (configPath == null) {
            Status.println("No autoload.txt found.");
            return;
        }

        Status.println("Found config at: " + configPath);
        byte[] configData = null;
        try {
            configData = readFileNative(configPath);
        } catch (IOException e) {
            Status.printStackTrace("Failed to read config", e);
        }
        
        List commands = AutoloadConfigParser.parseCommands(configData);
        if (commands.isEmpty()) {
            Status.println("Config is empty or could not be parsed.");
            return;
        }

        File configDir = new File(configPath).getParentFile();
        
        for (int i = 0; i < commands.size(); i++) {
            String command = (String) commands.get(i);
            try {
                processCommand(command, configDir);
            } catch (Exception e) {
                Status.printStackTrace("Error processing command: " + command, e);
            }
        }

        Status.println("Autoloader finished.");
        
        try {
            Thread.sleep(2000);
        } catch (InterruptedException ignored) {}
        //killApp();
    }

    private static String findConfig() {
        Status.println("Searching for " + AUTOLOAD_FILE + "...");

        String[] bases = new String[11];
        for (int i = 0; i <= 7; i++) bases[i] = "/mnt/usb" + i;
        bases[8] = "/data";
        bases[9] = "/mnt/disc";

        for (int i = 0; i < bases.length; i++) {
            String base = bases[i];
            
            // Check in subdirectory first
            String pathSub = base + "/" + AUTOLOAD_DIR + "/" + AUTOLOAD_FILE;
            Status.println("Checking: " + pathSub);
            if (existsNative(pathSub)) {
                Status.println("Found: " + pathSub);
                return pathSub;
            }

            // Check in root as fallback
            String pathRoot = base + "/" + AUTOLOAD_FILE;
            Status.println("Checking: " + pathRoot);
            if (existsNative(pathRoot)) {
                Status.println("Found: " + pathRoot);
                return pathRoot;
            }
        }

        return null;
    }

    private static void disableProxy(File f) {
        try {
            java.lang.reflect.Field proxyField = File.class.getDeclaredField("proxy");
            proxyField.setAccessible(true);
            proxyField.set(f, null);
        } catch (Throwable ignored) {}
    }

    private static boolean existsNative(String path) {
        if (sceKernelCheckReachability == 0) {
            File f = new File(path);
            disableProxy(f);
            boolean exists = f.exists();
            if (!exists) {
                // Try open
                int fd = (int) api.call(open, new Text(path).address(), 0L);
                if (fd >= 0) {
                    api.call(close, (long) fd);
                    return true;
                }
            }
            return exists;
        }
        try {
            Text pathText = new Text(path);
            int ret = (int) api.call(sceKernelCheckReachability, pathText.address());
            if (ret != 0) {
                int err = api.errno();
                if (err != 2) { // 2 = ENOENT
                    // Status.println("Reachability " + path + " failed with errno " + err);
                }
                return false;
            }
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    private static void processCommand(String command, File configDir) throws Exception {
        if (command.startsWith("@")) {
            String msg = command.substring(1).trim();
            // Replace literal \n with actual newline
            int idx;
            while ((idx = msg.indexOf("\\n")) != -1) {
                msg = msg.substring(0, idx) + "\n" + msg.substring(idx + 2);
            }
            Status.println("Notification: " + msg);
            NativeInvoke.sendNotificationRequest(msg);
            return;
        }

        if (command.startsWith("!")) {
            try {
                long delay = Long.parseLong(command.substring(1).trim());
                Status.println("Delaying for " + delay + "ms...");
                Thread.sleep(delay);
            } catch (Exception e) {
                Status.println("Invalid delay command: " + command);
            }
            return;
        }

        String lower = command.toLowerCase();
        File file = resolveFile(command, configDir);

        if (!existsNative(file.getAbsolutePath())) {
            Status.println("File not found: " + file.getAbsolutePath());
            return;
        }

        if (lower.endsWith(".jar")) {
            JarExecutor.execute(file);
        } else if (file.getName().equalsIgnoreCase("elfldr.elf")) {
            if (!isPortOpen(9021)) {
                Status.println("Loading custom elfldr.elf: " + file.getAbsolutePath());
                byte[] elfData = readFileNative(file.getAbsolutePath());
                ElfLoader.loadElf(elfData);
                Status.println("Waiting for custom elfldr to start...");
                Thread.sleep(4000);
            } else {
                Status.println("ELF loader already active, skipping custom elfldr.elf");
            }
        } else if (lower.endsWith(".elf") || lower.endsWith(".bin")) {
            executeElf(file);
        } else {
            Status.println("Unsupported command: " + command);
        }
    }

    private static File resolveFile(String path, File configDir) {
        File f = new File(path);
        if (f.isAbsolute()) {
            disableProxy(f);
            return f;
        }
        File res = new File(configDir, path);
        disableProxy(res);
        return res;
    }

    private static void executeElf(File elfFile) throws Exception {
        if (!isPortOpen(9021)) {
            Status.println("ELF loader not ready on port 9021, loading embedded elfldr...");
            ElfLoader.loadEmbeddedElf();
            Status.println("Waiting for elfldr to start...");
            Thread.sleep(4000);
            if (!isPortOpen(9021)) {
                Status.println("[-] Warning: port 9021 still not open after 4s. Attempting to send anyway...");
            }
        }

        Status.println("Sending ELF to port 9021: " + elfFile.getAbsolutePath());
        
        // Read ELF data
        byte[] elfData = readFileNative(elfFile.getAbsolutePath());
        
        // Send to port 9021
        sendToPort(9021, elfData);
    }

    private static boolean isPortOpen(int port) {
        Socket s = null;
        try {
            s = new Socket("127.0.0.1", port);
            return true;
        } catch (IOException e) {
            return false;
        } finally {
            if (s != null) {
                try { s.close(); } catch (IOException ignored) {}
            }
        }
    }

    private static void sendToPort(int port, byte[] data) throws IOException {
        Socket s = null;
        try {
            s = new Socket("127.0.0.1", port);
            OutputStream os = s.getOutputStream();
            os.write(data);
            os.flush();
            Status.println("Successfully sent " + data.length + " bytes to port " + port);
        } catch (IOException e) {
            Status.println("[-] Error sending data to port " + port + ": " + e.getMessage());
            throw e;
        } finally {
            if (s != null) {
                try { s.close(); } catch (IOException ignored) {}
            }
        }
    }

    private static byte[] readFileNative(String path) throws IOException {
        if (open == 0 || read == 0 || close == 0) throw new IOException("Native IO not available");
        
        Text pathText = new Text(path);
        int fd = (int) api.call(open, pathText.address(), 0 /* O_RDONLY */);
        if (fd < 0) throw new IOException("Failed to open " + path + " (errno=" + api.errno() + ")");
        
        try {
            java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream();
            long buf = api.malloc(4096);
            try {
                while (true) {
                    long n = api.call(read, (long) fd, buf, 4096L);
                    if (n <= 0) break;
                    byte[] chunk = new byte[(int) n];
                    api.memcpy(chunk, buf, n);
                    bos.write(chunk);
                }
            } finally {
                api.free(buf);
            }
            return bos.toByteArray();
        } finally {
            api.call(close, (long) fd);
        }
    }

    private static void killApp() {
        try {
            int pid = (int) api.call(getpid);
            Status.println("Killing process " + pid);
            api.call(kill, (long) pid, 9L);
        } catch (Throwable t) {
            Status.printStackTrace("Failed to kill app", t);
        }
    }
}
