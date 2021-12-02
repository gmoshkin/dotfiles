fn main() {
    // git aliases
    let output = std::process::Command::new("git")
        .arg("config")
        .arg("--global")
        .arg("--get-regexp")
        .arg("^alias.")
        .output()
        .unwrap()
        .stdout;
    let output = String::from_utf8_lossy(&output);
    let aliases = output
        .lines()
        .filter_map(|l| l.split_once(char::is_whitespace))
        .filter_map(|(alias, _)| alias.split_once('.'))
        .map(|(_, alias)| alias);
    for alias in aliases {
        println!("alias g{a}='git {a}'", a=alias)
    }
    // git commands
    let git_commands = std::fs::read_dir("/usr/lib/git-core")
        .unwrap()
        .filter_map(|f| f.ok())
        .filter(|f|
            f.metadata()
                .map(|md| !md.is_dir() &&
                    std::os::unix::fs::PermissionsExt::mode(&md.permissions()) & 0o111 != 0
                )
                .unwrap_or(false)
        )
        .filter_map(|f| f.file_name().into_string().ok());
    for git_command in git_commands {
        let alias = git_command.strip_prefix("git-").unwrap_or_else(|| &git_command);
        println!("alias g{a}='git {a}'", a=alias)
    }
    // cargo aliases
    let mut not_these = std::collections::HashSet::new();
    not_these.insert('d');
    for cmd in ["build", "clippy", "new", "init", "run", "search", "update"] {
        let first_char = cmd.chars().next().unwrap();
        println!("alias c{}='cargo {}'", first_char, cmd);
        not_these.insert(first_char);
    }
    // cargo commands
    let output = std::process::Command::new("cargo")
        .arg("--list")
        .output()
        .unwrap()
        .stdout;
    let output = String::from_utf8_lossy(&output);
    let cargo_commands = output
        .lines()
        .filter(|l| !l.contains("Installed"))
        .filter_map(|l| l.trim_start().split_once(char::is_whitespace))
        .map(|(cmd, _)| cmd)
        .filter(|cmd| cmd.len() != 1 || !not_these.contains(&cmd.chars().next().unwrap()));
    for cmd in cargo_commands {
        println!("alias c{c}='cargo {c}'", c=cmd)
    }
}
