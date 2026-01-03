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

/// Copy test config files to the temporary config directory
pub fn copy_test_config(plugin_dir: &PathBuf, config_dir: &PathBuf) {
    let test_config_dir = plugin_dir.join("tests/test_config");

    if test_config_dir.exists() {
        for entry in
            std::fs::read_dir(&test_config_dir).expect("Failed to read test_config directory")
        {
            let entry = entry.expect("Failed to get entry");
            let path = entry.path();
            let dest = config_dir.join(path.file_name().expect("Failed to get file name"));
            let _ = std::fs::copy(&path, dest);
        }
    }
}

/// Create plugin symlink in the config directory
pub fn create_plugin_symlink(plugin_dir: &PathBuf, config_dir: &PathBuf) {
    let plugins_dir = config_dir.join("plugins");
    std::fs::create_dir_all(&plugins_dir).expect("Failed to create plugins dir");
    let plugin_link = plugins_dir.join("what-size.yazi");

    #[cfg(unix)]
    std::os::unix::fs::symlink(&plugin_dir, &plugin_link).expect("Failed to create plugin symlink");

    #[cfg(windows)]
    std::os::windows::fs::symlink_dir(&plugin_dir, &plugin_link)
        .expect("Failed to create plugin symlink");
}
