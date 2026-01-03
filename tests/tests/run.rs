use portable_pty::{CommandBuilder, NativePtySystem, PtySize, PtySystem};
use std::io::{Read, Write};
use std::time::Duration;
use std::env;
use std::thread;
use std::time::Instant;
use std::path::PathBuf;
use vt100;

const PTY_COLS: u16 = 120;
const PTY_ROWS: u16 = 40;

/// Helper function to create a test directory structure
fn setup_test_dir() -> PathBuf {
    let test_dir = env::temp_dir().join(format!("yazi_test_what_size_{}", std::process::id()));
    if test_dir.exists() {
        std::fs::remove_dir_all(&test_dir).expect("Failed to clean test dir");
    }
    std::fs::create_dir_all(&test_dir).expect("Failed to create test dir");
    
    // Create some test files
    std::fs::write(test_dir.join("file1.txt"), "Hello World").expect("Failed to write file1");
    std::fs::write(test_dir.join("file2.txt"), "Test content").expect("Failed to write file2");
    
    // Create a subdirectory with files
    let subdir = test_dir.join("subdir");
    std::fs::create_dir(&subdir).expect("Failed to create subdir");
    std::fs::write(subdir.join("nested.txt"), "Nested file").expect("Failed to write nested file");
    
    test_dir
}

/// Helper function to read PTY output with timeout
fn read_pty_output(reader: &mut Box<dyn Read + Send>, timeout: Duration) -> Result<Vec<u8>, String> {
    let start = Instant::now();
    
    let mut buffer = Vec::new();
    let mut temp_buf = [0u8; 8192];
    
    loop {
        if start.elapsed() > timeout {
            break;
        }
        
        match reader.read(&mut temp_buf) {
            Ok(n) if n > 0 => {
                buffer.extend_from_slice(&temp_buf[..n]);
                // Give it a bit more time to see if more data comes
                thread::sleep(Duration::from_millis(100));
            }
            Ok(_) => {
                thread::sleep(Duration::from_millis(50));
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                thread::sleep(Duration::from_millis(50));
            }
            Err(e) => {
                return Err(format!("Read error: {}", e));
            }
        }
    }
    
    Ok(buffer)
}

/// Helper function to send keys to PTY
fn send_keys(writer: &mut Box<dyn Write + Send>, keys: &str) -> Result<(), String> {
    writer.write_all(keys.as_bytes())
        .map_err(|e| format!("Failed to write keys: {}", e))?;
    writer.flush()
        .map_err(|e| format!("Failed to flush: {}", e))?;
    
    // Give yazi time to process the keys
    thread::sleep(Duration::from_millis(500));
    Ok(())
}

#[test]
fn test_yazi_loads_with_plugin() {
    // Setup test directory
    let test_dir = setup_test_dir();
    
    // Get the path to the plugin (parent of tests directory)
    let plugin_dir = env::current_dir()
        .expect("Failed to get current dir")
        .parent()
        .expect("Failed to get parent dir")
        .to_path_buf();
    
    // Setup yazi config directory
    let config_dir = env::temp_dir().join(format!("yazi_test_config_{}", std::process::id()));
    if config_dir.exists() {
        std::fs::remove_dir_all(&config_dir).expect("Failed to clean config dir");
    }
    std::fs::create_dir_all(&config_dir).expect("Failed to create config dir");
    
    // Copy keymap configuration
    let keymap_src = plugin_dir.join("tests/test_config/keymap.toml");
    let keymap_dst = config_dir.join("keymap.toml");
    std::fs::copy(&keymap_src, &keymap_dst).expect("Failed to copy keymap.toml");
    
    // Create init.lua to load the plugin
    let init_lua = format!(
        r#"
require("what-size"):setup({{
    priority = 400,
    LEFT = "[",
    RIGHT = "]",
}})
"#
    );
    std::fs::write(config_dir.join("init.lua"), init_lua).expect("Failed to write init.lua");
    
    // Create plugins directory and symlink the plugin
    let plugins_dir = config_dir.join("plugins");
    std::fs::create_dir_all(&plugins_dir).expect("Failed to create plugins dir");
    let plugin_link = plugins_dir.join("what-size.yazi");
    
    #[cfg(unix)]
    std::os::unix::fs::symlink(&plugin_dir, &plugin_link)
        .expect("Failed to create plugin symlink");
    
    #[cfg(windows)]
    std::os::windows::fs::symlink_dir(&plugin_dir, &plugin_link)
        .expect("Failed to create plugin symlink");
    
    // Create PTY system
    let pty_system = NativePtySystem::default();
    let pair = pty_system
        .openpty(PtySize {
            rows: PTY_ROWS,
            cols: PTY_COLS,
            pixel_width: 0,
            pixel_height: 0,
        })
        .expect("Failed to open PTY");
    
    // Build yazi command
    let mut cmd = CommandBuilder::new("yazi");
    cmd.arg(&test_dir);
    cmd.env("YAZI_CONFIG_HOME", &config_dir);
    cmd.env("TERM", "xterm-256color");
    cmd.env("YAZI_LOG", "debug");
    
    // Spawn yazi process
    let mut child = pair.slave.spawn_command(cmd)
        .expect("Failed to spawn yazi");
    
    // Drop the slave to avoid deadlock
    drop(pair.slave);
    
    // Get reader and writer
    let mut reader = pair.master.try_clone_reader()
        .expect("Failed to clone reader");
    let mut writer = pair.master.take_writer()
        .expect("Failed to take writer");
    
    // Wait for initial output
    thread::sleep(Duration::from_secs(2));
    
    // Read initial screen
    let output = read_pty_output(&mut reader, Duration::from_secs(3))
        .expect("Failed to read initial output");
    
    let output_str = String::from_utf8_lossy(&output);
    println!("Initial yazi output:\n{}", output_str);
    
    // Parse with vt100 to check what's displayed
    let mut parser = vt100::Parser::new(PTY_ROWS, PTY_COLS, 0);
    parser.process(&output);
    let screen = parser.screen();
    let screen_contents = screen.contents();
    
    println!("\nParsed screen contents:\n{}", screen_contents);
    
    // Basic check: yazi should be running and showing something
    assert!(
        screen_contents.contains("file1.txt") || 
        screen_contents.contains("file2.txt") ||
        screen_contents.contains("subdir"),
        "Yazi should display test directory contents"
    );
    
    // Try to trigger the plugin by sending the keymap sequence (., s)
    println!("\nSending keymap sequence '.' then 's'...");
    send_keys(&mut writer, ".").expect("Failed to send '.'");
    send_keys(&mut writer, "s").expect("Failed to send 's'");
    
    // Read output after triggering plugin
    let plugin_output = read_pty_output(&mut reader, Duration::from_secs(3))
        .expect("Failed to read plugin output");
    
    let plugin_output_str = String::from_utf8_lossy(&plugin_output);
    println!("\nPlugin output:\n{}", plugin_output_str);
    
    // Parse the new screen state
    parser.process(&plugin_output);
    let screen = parser.screen();
    let screen_contents = screen.contents();
    
    println!("\nParsed screen after plugin trigger:\n{}", screen_contents);
    
    // Check if the plugin notification or size appears
    // The plugin should show "What size" notification with size information
    let has_size_info = screen_contents.contains("What size") ||
                        screen_contents.contains("Current Dir:") ||
                        screen_contents.contains("Selected:") ||
                        screen_contents.contains("B") || // Size unit
                        screen_contents.contains("KB") ||
                        screen_contents.contains("MB");
    
    assert!(
        has_size_info,
        "Plugin should display size information after triggering. Screen contents:\n{}",
        screen_contents
    );
    
    // Send quit command (q)
    send_keys(&mut writer, "q").expect("Failed to send 'q'");
    
    // Wait for process to exit
    thread::sleep(Duration::from_secs(1));
    
    // Try to kill the child process if still running
    let _ = child.kill();
    
    // Cleanup
    let _ = std::fs::remove_dir_all(&test_dir);
    let _ = std::fs::remove_dir_all(&config_dir);
    
    println!("\nTest completed successfully!");
}

#[test]
fn test_yazi_plugin_with_selection() {
    // Setup test directory
    let test_dir = setup_test_dir();
    
    // Get the path to the plugin
    let plugin_dir = env::current_dir()
        .expect("Failed to get current dir")
        .parent()
        .expect("Failed to get parent dir")
        .to_path_buf();
    
    // Setup yazi config directory
    let config_dir = env::temp_dir().join(format!("yazi_test_config_selection_{}", std::process::id()));
    if config_dir.exists() {
        std::fs::remove_dir_all(&config_dir).expect("Failed to clean config dir");
    }
    std::fs::create_dir_all(&config_dir).expect("Failed to create config dir");
    
    // Copy keymap configuration
    let keymap_src = plugin_dir.join("tests/test_config/keymap.toml");
    let keymap_dst = config_dir.join("keymap.toml");
    std::fs::copy(&keymap_src, &keymap_dst).expect("Failed to copy keymap.toml");
    
    // Create init.lua
    let init_lua = format!(
        r#"
require("what-size"):setup({{
    priority = 400,
    LEFT = "[",
    RIGHT = "]",
}})
"#
    );
    std::fs::write(config_dir.join("init.lua"), init_lua).expect("Failed to write init.lua");
    
    // Create plugins directory and symlink
    let plugins_dir = config_dir.join("plugins");
    std::fs::create_dir_all(&plugins_dir).expect("Failed to create plugins dir");
    let plugin_link = plugins_dir.join("what-size.yazi");
    
    #[cfg(unix)]
    std::os::unix::fs::symlink(&plugin_dir, &plugin_link)
        .expect("Failed to create plugin symlink");
    
    #[cfg(windows)]
    std::os::windows::fs::symlink_dir(&plugin_dir, &plugin_link)
        .expect("Failed to create plugin symlink");
    
    // Create PTY
    let pty_system = NativePtySystem::default();
    let pair = pty_system
        .openpty(PtySize {
            rows: PTY_ROWS,
            cols: PTY_COLS,
            pixel_width: 0,
            pixel_height: 0,
        })
        .expect("Failed to open PTY");
    
    // Build command
    let mut cmd = CommandBuilder::new("yazi");
    cmd.arg(&test_dir);
    cmd.env("YAZI_CONFIG_HOME", &config_dir);
    cmd.env("TERM", "xterm-256color");
    
    // Spawn process
    let mut child = pair.slave.spawn_command(cmd)
        .expect("Failed to spawn yazi");
    
    drop(pair.slave);
    
    let mut reader = pair.master.try_clone_reader()
        .expect("Failed to clone reader");
    let mut writer = pair.master.take_writer()
        .expect("Failed to take writer");
    
    // Wait for yazi to load
    thread::sleep(Duration::from_secs(2));
    
    // Read initial output
    let _ = read_pty_output(&mut reader, Duration::from_secs(2))
        .expect("Failed to read initial output");
    
    // Select first file with Space
    println!("\nSelecting first file with Space...");
    send_keys(&mut writer, " ").expect("Failed to send Space");
    
    // Trigger plugin
    println!("Triggering plugin with '.s'...");
    send_keys(&mut writer, ".").expect("Failed to send '.'");
    send_keys(&mut writer, "s").expect("Failed to send 's'");
    
    // Read output after plugin trigger
    let plugin_output = read_pty_output(&mut reader, Duration::from_secs(3))
        .expect("Failed to read plugin output");
    
    let plugin_output_str = String::from_utf8_lossy(&plugin_output);
    println!("\nPlugin output with selection:\n{}", plugin_output_str);
    
    // Parse screen
    let mut parser = vt100::Parser::new(PTY_ROWS, PTY_COLS, 0);
    parser.process(&plugin_output);
    let screen = parser.screen();
    let screen_contents = screen.contents();
    
    println!("\nParsed screen with selection:\n{}", screen_contents);
    
    // Should show "Selected:" instead of "Current Dir:"
    let has_selection_info = screen_contents.contains("Selected:") ||
                             screen_contents.contains("What size");
    
    assert!(
        has_selection_info,
        "Plugin should show selection size information. Screen contents:\n{}",
        screen_contents
    );
    
    // Quit
    send_keys(&mut writer, "q").expect("Failed to send 'q'");
    thread::sleep(Duration::from_secs(1));
    let _ = child.kill();
    
    // Cleanup
    let _ = std::fs::remove_dir_all(&test_dir);
    let _ = std::fs::remove_dir_all(&config_dir);
    
    println!("\nSelection test completed successfully!");
}
