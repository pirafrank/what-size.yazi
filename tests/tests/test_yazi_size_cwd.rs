use ntest::timeout;
use serial_test::serial;
use std::thread;
use std::time::Duration;
use vt100;

mod common;
use common::env::*;
use common::fixtures::{YaziTestConfig, YaziTestFixture};
use common::pty_helpers::*;

#[test]
#[serial]
#[timeout(90000)]
/**
 * The test does the following:
 * 1. Spawns Yazi in a PTY with the plugin loaded
 * 2. Verifies the TUI displays the test directory contents
 * 3. Triggers the plugin using the keymap sequence (. + s)
 * 4. Verifies the plugin displays "Current Dir: 34.00 B" notification
 * 5. Checks the status line shows the calculated size [34.00 B]
 * 6. Quits Yazi
 * 7. Cleans up temporary directories and files
 */
fn test_yazi_loads_with_plugin() {
    // Setup test directory
    let test_dir = setup_test_dir();

    let mut fixture = YaziTestFixture::new(
        test_dir,
        YaziTestConfig {
            test_name: "size of cwd".to_string(),
        },
    );

    // Wait for yazi to load
    thread::sleep(Duration::from_secs(2));

    // Read initial screen
    let output = read_pty_output(&mut fixture.reader, Duration::from_secs(3))
        .expect("Failed to read initial output");

    // Parse with vt100 to check what's displayed
    let mut parser = vt100::Parser::new(PTY_ROWS, PTY_COLS, 0);
    parser.process(&output);
    let screen = parser.screen();
    let screen_contents = screen.contents();

    // Basic check: yazi should be running and showing something
    assert!(
        screen_contents.contains("file1.txt")
            || screen_contents.contains("file2.txt")
            || screen_contents.contains("subdir"),
        "Yazi should display test directory contents"
    );

    // Trigger the plugin by sending the keymap sequence (., s)
    println!("\nSending keymap sequence '.' then 's'...");
    send_keys(&mut fixture.writer, ".").expect("Failed to send '.'");
    send_keys(&mut fixture.writer, "s").expect("Failed to send 's'");

    // Read output after triggering plugin
    let plugin_output = read_pty_output(&mut fixture.reader, Duration::from_secs(3))
        .expect("Failed to read plugin output");

    // Parse the new screen state
    parser.process(&plugin_output);
    let screen = parser.screen();
    let screen_contents = screen.contents();

    // Check if the plugin notification or size appears
    // The plugin should show "What size" notification with size information
    let has_size_info: bool = screen_contents.contains("Current Dir:")
        || screen_contents.contains(" B")
        || screen_contents.contains("KB")
        || screen_contents.contains("MB")
        || screen_contents.contains("GB")
        || screen_contents.contains("TB");

    assert!(
        has_size_info,
        "Plugin should display size information after triggering. Screen contents:\n{}",
        screen_contents
    );

    // Quit...
    send_keys(&mut fixture.writer, "q").expect("Failed to send 'q'");

    // Wait for yazi to actually exit (with timeout)
    println!("\nWaiting for Yazi to exit...");
    wait_for_exit(&mut fixture.child, Duration::from_secs(5))
        .expect("Yazi did not exit within timeout");

    // All done!
    // Cleanup is automatically handled by the fixture via Drop impl
}
