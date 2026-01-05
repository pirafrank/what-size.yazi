use portable_pty::Child;
use std::io::{Read, Write};
use std::thread;
use std::time::Duration;
use std::time::Instant;

/// Helper function to read PTY output with timeout
pub fn read_pty_output(
    reader: &mut Box<dyn Read + Send>,
    timeout: Duration,
) -> Result<Vec<u8>, String> {
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
pub fn send_keys(writer: &mut Box<dyn Write + Send>, keys: &str) -> Result<(), String> {
    writer
        .write_all(keys.as_bytes())
        .map_err(|e| format!("Failed to write keys: {}", e))?;
    writer
        .flush()
        .map_err(|e| format!("Failed to flush: {}", e))?;

    // Give yazi time to process the keys
    thread::sleep(Duration::from_millis(500));
    Ok(())
}

/// Helper function to wait for a process to exit with timeout
#[allow(dead_code)]
pub fn wait_for_exit(
    child: &mut Box<dyn Child + Send + Sync>,
    timeout: Duration,
) -> Result<(), String> {
    let start = Instant::now();

    loop {
        match child.try_wait() {
            Ok(Some(exit_status)) => {
                println!("Process exited with status: {:?}", exit_status);
                return Ok(());
            }
            Ok(None) => {
                // Process still running
                if start.elapsed() > timeout {
                    return Err(format!("Process did not exit within {:?} timeout", timeout));
                }
                thread::sleep(Duration::from_millis(100));
            }
            Err(e) => {
                return Err(format!("Error waiting for process: {}", e));
            }
        }
    }
}
