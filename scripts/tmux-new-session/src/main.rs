fn body() -> Result<(), Box<dyn std::error::Error>> {
    let mut raw = String::with_capacity(128);
    std::io::Read::read_to_string(&mut std::io::stdin(), &mut raw)?;

    let path = std::path::Path::new(raw.trim());

    let full_path = path.to_str().ok_or_else(|| format!("{:?} is not str", path))?;

    let filename = path.file_name()
        .ok_or_else(|| format!("{:?} has no filename", path))?
        .to_str()
        .ok_or_else(|| format!("{:?}.filename is not str", path))?;

    let raw = std::process::Command::new("tmux")
        .args(["display", "-p", "#{S:#{P:#{?#{==:#P,0},#S:#{pane_current_path};,}}}"])
        .output()?
        .stdout;

    let sessions = std::str::from_utf8(&raw)?
        .split(';')
        .flat_map(|l| l.split_once(':'))
        .collect::<std::collections::HashMap<_, _>>();

    for n in 1.. {
        let session = filename.split(|c: char| !c.is_alphanumeric())
            .flat_map(|s| s.get(0..(n.min(s.len()))))
            .collect::<Vec<_>>()
            .join("");

        match sessions.get(&session.as_str()).copied() {
            Some(p) if p == full_path => {
                run("tmux", ["switch-client", "-t", &session])?;
                break;
            }
            None => {
                run("tmux", ["new-session", "-d", "-s", &session, "-c", &full_path])?;
                run("tmux", ["switch-client", "-t", &session])?;
                break
            }
            Some(p) => {
                println!("{} != {}, trying again", p, full_path);
                continue
            }
        }
    }

    Ok(())
}

fn main() {
    if let Err(e) = body() {
        std::process::Command::new("tmux")
            .args(["display", &e.to_string()])
            .status()
            .unwrap();
    }
}

fn run(
    cmd: impl AsRef<std::ffi::OsStr>,
    args: impl IntoIterator<Item = impl AsRef<std::ffi::OsStr>>
) -> Result<(), Box<dyn std::error::Error>> {
    let output = std::process::Command::new(cmd).args(args).output()?;
    if !output.status.success() {
        Err(String::from_utf8_lossy(&output.stderr))?
    }
    Ok(())
}
