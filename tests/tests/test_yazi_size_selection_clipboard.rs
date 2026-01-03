use serial_test::serial;
use std::thread;
use std::time::Duration;
use cli_clipboard::{ClipboardContext, ClipboardProvider};

mod common;
use common::env::*;
use common::fixtures::{YaziTestConfig, YaziTestFixture};
use common::pty_helpers::*;

#[test]
#[serial]
/**
 * The test does the following:
 * 1. Spawns Yazi in a PTY with the plugin loaded
 * 2. Verifies the TUI displays the test directory contents
 * 3. Selects a file with Space
 * 4. Triggers the plugin using the keymap sequence (. + y)
 * 5. Verifies the plugin displays "Copied to clipboard" notification
 * 6. Verifies the clipboard contains the size information
 * 7. Quits Yazi
 * 8. Cleans up temporary directories and files
 */
fn test_yazi_plugin_copies_to_clipboard() {
    // Setup test directory
    let test_dir = setup_test_dir();

    let mut fixture = YaziTestFixture::new(
        test_dir,
        YaziTestConfig {
            test_name: "clipboard_copy".to_string(),
        },
    );

    // Wait for yazi to load
    thread::sleep(Duration::from_secs(2));

    // Read initial output
    let _ = read_pty_output(&mut fixture.reader, Duration::from_secs(2))
        .expect("Failed to read initial output");

    // Clear clipboard before test
    let mut ctx = ClipboardContext::new()
        .expect("Failed to create clipboard context");
    ctx.set_contents(String::new())
        .expect("Failed to clear clipboard");

    // Select first file with Space
    println!("\nSelecting first file with Space...");
    send_keys(&mut fixture.writer, " ").expect("Failed to send Space");

    // Trigger plugin w/ clipboard flag (".y" sends to clipboard)
    println!("Triggering plugin with '.y' (clipboard mode)...");
    send_keys(&mut fixture.writer, ".").expect("Failed to send '.'");
    send_keys(&mut fixture.writer, "y").expect("Failed to send 'y'");

    // Give time for clipboard operation
    thread::sleep(Duration::from_secs(1));

    // Read terminal output
    let plugin_output = read_pty_output(&mut fixture.reader, Duration::from_secs(2))
        .expect("Failed to read plugin output");

    let plugin_output_str = String::from_utf8_lossy(&plugin_output);
    println!("\nPlugin output:\n{}", plugin_output_str);

    // Parse screen to verify TUI output
    let mut parser = vt100::Parser::new(PTY_ROWS, PTY_COLS, 0);
    parser.process(&plugin_output);
    let screen = parser.screen();
    let screen_contents = screen.contents();

    println!("\nParsed screen:\n{}", screen_contents);

    // Verify TUI shows the notification with "Copied to clipboard"
    assert!(
        screen_contents.contains("Copied to clipboard") && screen_contents.contains("Selected:"),
        "TUI should show 'Copied to clipboard' and 'Selected:' messages. Screen contents:\n{}",
        screen_contents
    );

    // Verify clipboard actually contains the size
    let clipboard_content = ctx.get_contents()
        .expect("Failed to read clipboard");
    
    println!("\nClipboard content: '{}'", clipboard_content);

    // Check that clipboard contains a size string (e.g., "11.00 B")
    let has_size = clipboard_content.contains(" B") 
        || clipboard_content.contains("KB")
        || clipboard_content.contains("MB")
        || clipboard_content.contains("GB")
        || clipboard_content.contains("TB");

    assert!(
        has_size,
        "Clipboard should contain size information. Found: '{}'",
        clipboard_content
    );

    // Quit
    send_keys(&mut fixture.writer, "q").expect("Failed to send 'q'");
    // ... and wait for process to exit
    thread::sleep(Duration::from_secs(1));

    // All done!
    // Cleanup is automatically handled by the fixture via Drop impl
}
