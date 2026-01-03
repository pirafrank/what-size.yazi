use std::env;
use std::path::PathBuf;

pub const PTY_COLS: u16 = 120;
pub const PTY_ROWS: u16 = 40;

/// Helper function to create a test directory with sample files
pub fn setup_test_dir() -> PathBuf {
    let test_dir = env::temp_dir().join(format!("yazi_test_what_size_{}", std::process::id()));

    // Clean up if it exists
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
