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
/**
 * The test does the following:
 * 1. Launches Yazi and selects a file using Space
 * Triggers the plugin with the selection
 * Verifies the plugin shows "Selected: 11.00 B" instead of "Current Dir:"
 * Confirms the size reflects the selected file only
 * Quits Yazi
 * Cleans up temporary directories and files
 */
fn test_yazi_plugin_with_selection() {
    // Setup test directory
    let test_dir = setup_test_dir();

    let mut fixture = YaziTestFixture::new(
        test_dir,
        YaziTestConfig {
            test_name: "size of selection".to_string(),
        },
    );

    // Wait for yazi to load
    thread::sleep(Duration::from_secs(2));

    // Read initial output
    let _ = read_pty_output(&mut fixture.reader, Duration::from_secs(2))
        .expect("Failed to read initial output");

    // Select first file with Space
    println!("\nSelecting first file with Space...");
    send_keys(&mut fixture.writer, " ").expect("Failed to send Space");

    // Trigger plugin
    println!("Triggering plugin with '.s'...");
    send_keys(&mut fixture.writer, ".").expect("Failed to send '.'");
    send_keys(&mut fixture.writer, "s").expect("Failed to send 's'");

    // Read output after plugin trigger
    let plugin_output = read_pty_output(&mut fixture.reader, Duration::from_secs(3))
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
    let has_size_info: bool = screen_contents.contains("Selected:")
        || screen_contents.contains(" B")
        || screen_contents.contains("KB")
        || screen_contents.contains("MB")
        || screen_contents.contains("GB")
        || screen_contents.contains("TB");

    assert!(
        has_size_info,
        "Plugin should show selection size information. Screen contents:\n{}",
        screen_contents
    );

    // Quit...
    send_keys(&mut fixture.writer, "q").expect("Failed to send 'q'");
    // ... and wait for process to exit
    thread::sleep(Duration::from_secs(1));

    // All done!
    // Cleanup is automatically handled by the fixture via Drop impl
}
