use super::env::*;
use portable_pty::{Child, CommandBuilder, NativePtySystem, PtySize, PtySystem};
use std::env;
use std::io::{Read, Write};
use std::path::PathBuf;

/// Configuration for Yazi test setup
pub struct YaziTestConfig {
    pub test_name: String,
}

impl Default for YaziTestConfig {
    fn default() -> Self {
        Self {
            test_name: "default".to_string(),
        }
    }
}

/// A complete Yazi test environment with PTY and config
pub struct YaziTestFixture {
    pub test_dir: PathBuf,
    pub config_dir: PathBuf,
    pub child: Box<dyn Child + Send + Sync>,
    pub reader: Box<dyn Read + Send>,
    pub writer: Box<dyn Write + Send>,
}

impl YaziTestFixture {
    /// Create a new Yazi test harness with the given configuration
    pub fn new(test_dir: PathBuf, config: YaziTestConfig) -> Self {
        // Get plugin directory
        let plugin_dir = env::current_dir()
            .expect("Failed to get current dir")
            .parent()
            .expect("Failed to get parent dir")
            .to_path_buf();

        // Setup config directory
        let config_dir = env::temp_dir().join(format!(
            "yazi_test_config_{}_{}",
            config.test_name,
            std::process::id()
        ));

        if config_dir.exists() {
            std::fs::remove_dir_all(&config_dir).expect("Failed to clean config dir");
        }
        std::fs::create_dir_all(&config_dir).expect("Failed to create config dir");

        // Copy test config files
        copy_test_config(&plugin_dir, &config_dir);

        // Create plugin symlink
        create_plugin_symlink(&plugin_dir, &config_dir);

        // Create PTY and spawn Yazi
        let (child, reader, writer) = spawn_yazi(&test_dir, &config_dir);

        Self {
            test_dir,
            config_dir,
            child,
            reader,
            writer,
        }
    }
}

impl Drop for YaziTestFixture {
    fn drop(&mut self) {
        // Kill the process
        let _ = self.child.kill();

        // Cleanup directories
        let _ = std::fs::remove_dir_all(&self.test_dir);
        let _ = std::fs::remove_dir_all(&self.config_dir);
    }
}

/// Spawn Yazi in a PTY and return the child process and I/O handles
fn spawn_yazi(
    test_dir: &PathBuf,
    config_dir: &PathBuf,
) -> (
    Box<dyn Child + Send + Sync>,
    Box<dyn Read + Send>,
    Box<dyn Write + Send>,
) {
    let pty_system = NativePtySystem::default();
    let pair = pty_system
        .openpty(PtySize {
            rows: PTY_ROWS,
            cols: PTY_COLS,
            pixel_width: 0,
            pixel_height: 0,
        })
        .expect("Failed to open PTY");

    let mut cmd = CommandBuilder::new("yazi");
    cmd.arg(&test_dir);
    cmd.env("YAZI_CONFIG_HOME", &config_dir);
    cmd.env("TERM", "xterm-256color");
    cmd.env("YAZI_LOG", "debug");

    let child = pair.slave.spawn_command(cmd).expect("Failed to spawn yazi");

    // Drop slave to avoid I/O conflicts
    drop(pair.slave);

    let reader = pair
        .master
        .try_clone_reader()
        .expect("Failed to clone reader");
    let writer = pair.master.take_writer().expect("Failed to take writer");

    (child, reader, writer)
}
