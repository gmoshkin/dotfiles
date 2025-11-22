use std::collections::HashMap;
use std::os::unix::net::UnixStream;
use std::io::Read;
use std::io::Write;
use std::process::exit;

#[derive(Debug, serde::Deserialize)]
#[allow(dead_code)]
struct Resp<T> {
    msg_type: u32,
    sync: u32,
    err: Option<(i32, String)>,
    value: T,
}

const MSG_TYPE_REQ: u32 = 0;

#[derive(Debug, serde::Serialize)]
struct Req {
    msg_type: u32,
    sync: u32,
    proc: &'static str,
    args: Vec<Value>,
}

impl Req {
    fn arg(mut self, a: impl Into<Value>) -> Self {
        self.args.push(a.into());
        self
    }
}

macro_rules! req {
    ($proc:expr $(,$arg:expr)* $(,)?) => {
        Req {
            msg_type: MSG_TYPE_REQ,
            sync: 420,
            proc: $proc,
            args: vec![ $( $arg.into() ),* ],
        }
    }
}

macro_rules! tmux {
    ($($arg:expr),+ $(,)?) => {{
        let cmd_out = std::process::Command::new("tmux")
            .args([$($arg, )+])
            .output().unwrap();
        String::from_utf8_lossy(&cmd_out.stdout).trim().to_string()
    }}
}

#[derive(Debug, serde::Serialize, serde::Deserialize)]
#[serde(untagged)]
enum Value {
    Str(String),
    Int(i64),
    Ext(Ext),
    Bool(bool),
}

#[derive(Debug)]
struct Ext {
    kind: u8,
    bytes: Vec<u8>,
}

impl Ext {
    const KIND_BUF: u8 = 0;
    const KIND_WIN: u8 = 1;

    fn buf(&self) -> Option<i64> {
        if self.kind != Self::KIND_BUF {
            return None;
        }
        Some(rmp_serde::from_slice(&self.bytes).unwrap())
    }

    fn win(&self) -> Option<i64> {
        if self.kind != Self::KIND_WIN {
            return None;
        }
        Some(rmp_serde::from_slice(&self.bytes).unwrap())
    }
}

impl serde::Serialize for Ext {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        #[derive(serde::Serialize)]
        struct _ExtStruct((u8, serde_bytes::ByteBuf));
        _ExtStruct((self.kind, serde_bytes::ByteBuf::from(&*self.bytes))).serialize(serializer)
    }
}

impl<'de> serde::Deserialize<'de> for Ext {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        #[derive(serde::Deserialize)]
        struct _ExtStruct((u8, serde_bytes::ByteBuf));

        let _ExtStruct((kind, bytes)) = serde::Deserialize::deserialize(deserializer)?;
        let bytes = bytes.into_vec();
        Ok(Ext { kind, bytes })
    }
}


impl<'a> From<&'a str> for Value { fn from(v: &'a str) -> Self { Self::Str(v.into()) } }
impl     From<String > for Value { fn from(v: String ) -> Self { Self::Str(v)        } }
impl     From<i64    > for Value { fn from(v: i64    ) -> Self { Self::Int(v)        } }
impl     From<bool   > for Value { fn from(v: bool   ) -> Self { Self::Bool(v)       } }

fn main() {
    let mut args = std::env::args();
    args.next();
    let mut open_file_line_col = None;
    while let Some(arg) = args.next() {
        // dbg!(&arg);
        match &*arg {
            "open" => {
                let file_line_col_raw: String;

                let arg = args.next().expect("expected argument after 'open'");
                'get_file_line_col_raw: {
                    if arg.is_empty() {
                        // TODO: what if file path starts on previous line and
                        // wraps to the one the cursor is in, or vice versa.
                        // Example:
                        // ```
                        // oi mate, you done fucked up at this loc bruv: path/to\n
                        // /the/file.ext:420:69
                        // ```
                        // Looks like a pain in my ass to implement this.
                        // copy_cursor_line aint gon help. Gotta tmux
                        // capture-pane and read lines above (or below). Do I
                        // arbitrarily limmit the length of the file if it spans
                        // more than 2 lines? Yes probably, if it's more than 10
                        // lines definitely go fuck yourself, bruv.
                        //
                        // Also maybe lets rewrite this in jai, ye?
                        let out = tmux!["display", "-p", "#{copy_cursor_x}@#{copy_cursor_line}"];
                        let (crsr_col, line_contents) = out.split_once("@").unwrap();
                        if line_contents.is_empty() {
                            panic!("empty line")
                        }

                        let crsr_col = crsr_col.parse::<usize>().unwrap();
                        let Some(first) = line_contents.find(|c| !is_file_loc_char(c)) else {
                            // whole line is a file loc <file>:<line>:<col>
                            file_line_col_raw = line_contents.into();
                            break 'get_file_line_col_raw;
                        };

                        let mut start = 0;
                        let mut end = first;
                        let line_end = line_contents.len();
                        loop {
                            // dbg!(start..end, &line_contents[start..end], crsr_col);
                            if start > crsr_col {
                                panic!("couldn't find filename in line '{line_contents}'")
                            }
                            if end > crsr_col {
                                file_line_col_raw = line_contents[start..end].into();
                                break 'get_file_line_col_raw;
                            }
                            // need to do this because line_contents[end + 1..]
                            // may panic if end + 1 points in the middle of a
                            // multibyte unicode character
                            let Some(end_char) = line_contents.chars().skip(end).next() else {
                                println!("couldn't find filename in line '{line_contents}'");
                                exit(1);
                            };
                            let end_char_len = end_char.len_utf8();
                            let line_tail = &line_contents[end + end_char_len..];
                            let Some(new_start) = line_tail.find(|c| is_file_loc_char(c)) else {
                                panic!("couldn't find filename in line '{line_contents}'")
                            };
                            start = end + 1 + new_start;
                            let new_end = line_contents[start..].find(|c| !is_file_loc_char(c)).unwrap_or_else(|| line_end - start);
                            end = start + new_end;
                        }
                    } else {
                        file_line_col_raw = arg.into();
                    }
                }

                let mut iter = file_line_col_raw.split(':');
                let mut filename = iter.next().expect("expected a filename").to_owned();
                if filename.len() == 1 && filename[0..1].chars().all(|c| c.is_alphabetic()) {
                    filename.push(':');
                    let Some(rest_of_filepath) = iter.next() else {
                        panic!("expected rest of file path after windows volume '{}'", filename);
                    };
                    filename.push_str(&rest_of_filepath);
                }
                let mut file_line_col = (filename, None, None);
                let mut line_str = "";
                let mut col_str = "";
                let mut col_sep = "";
                if let Some(after_file) = iter.next() {
                    if let Some((line, col)) = after_file.split_once(',') {
                        line_str = line;
                        col_str = col;
                        col_sep = ",";
                    } else {
                        line_str = after_file;
                    }
                }
                if col_str.is_empty() {
                    if let Some(col) = iter.next() {
                        col_str = col;
                        col_sep = ":";
                    }
                }
                if !line_str.is_empty() {
                    let line = line_str.parse::<u64>().expect("expected line number after <filename>:{here}");
                    file_line_col.1 = Some(line);
                }
                if !col_str.is_empty() {
                    let col = match col_str.parse::<u64>() {
                        Ok(col) => col,
                        Err(e) => {
                            println!("{e}");
                            println!("expected column number after <file>:<line>{col_sep}{{here}}");
                            std::process::exit(1);
                        }
                    };
                    file_line_col.2 = Some(col);
                }

                open_file_line_col = Some(file_line_col);
            }
            unknown => {
                panic!("unknown command: '{unknown}'");
            }
        }
    }

    let my_pane_id =
        if let Ok(tmux_pane) = std::env::var("TMUX_PANE") {
            tmux_pane
        } else {
            tmux!["display", "-p", "#D"]
        };
    // dbg!(&my_pane_id);

    let cmd_out = tmux!["list-panes", "-aF", "#D:#S"];
    let mut my_sess_name = "";
    let mut sess_by_pane_id = HashMap::new();
    for line in cmd_out.lines() {
        let (pane_id, sess_name) = line.split_once(':').unwrap();
        sess_by_pane_id.insert(pane_id, sess_name);
        if pane_id == my_pane_id {
            my_sess_name = sess_name;
        }
    }

    let mut nvim_conn_and_pane = None;
    if let Ok(entries) = std::fs::read_dir("/run/user") {
        'outer: for dir_entry in entries {
            let Ok(dir_entry) = dir_entry else { continue; };
            if !dir_entry.file_type().unwrap().is_dir() { continue; }
            let dir_path = dir_entry.path().into_os_string().into_string().unwrap();
            let Some(res) = look_for_server_file(&dir_path, my_sess_name, &sess_by_pane_id) else {
                continue;
            };
            nvim_conn_and_pane = Some(res);
            break;
        }
    }
    if nvim_conn_and_pane.is_none() {
        nvim_conn_and_pane = look_for_server_file("/mnt/wslg/runtime-dir", my_sess_name, &sess_by_pane_id);
    }

    if nvim_conn_and_pane.is_none() {
        for dir_entry in std::fs::read_dir("/tmp").unwrap() {
            let dir_entry = dir_entry.unwrap();
            if !dir_entry.file_type().unwrap().is_dir() { continue; }

            let file_path = dir_entry.path();
            let file_name = file_path.file_name().unwrap();
            if !file_name.to_str().unwrap().starts_with("nvim") { continue; }

            let sock_path = file_path.join("0");
            if !sock_path.try_exists().unwrap() { continue; }

            let res = UnixStream::connect(&sock_path);
            let Ok(mut conn) = res else { continue; };

            // conn.set_read_timeout(Some(std::time::Duration::from_millis(500))).unwrap();
            let req = Req {
                msg_type: MSG_TYPE_REQ,
                sync: 420,
                proc: "nvim_eval",
                args: vec!["$TMUX_PANE".into()],
            };

            let nvim_pane: String = rpc(&mut conn, &req);
            let Some(nvim_sess) = sess_by_pane_id.get(&*nvim_pane) else {
                eprintln!("'{}' is not a known tmux pane", nvim_pane);
                continue;
            };

            if *nvim_sess == my_sess_name {
                println!("socket: {}", sock_path.display());
                nvim_conn_and_pane = Some((conn, nvim_pane));
                break;
            }
        }
    }

    let Some((mut nvim_conn, nvim_pane)) = nvim_conn_and_pane else {
        panic!("nvim is not running in current tmux session '{my_sess_name}'");
    };

    if let Some((file, line, col)) = open_file_line_col {
        let mut cmd = "e ".to_owned();
        if file[0..1].chars().all(|c| c.is_alphabetic()) && &file[1..2] == ":" {
            // Windows path
            let mut linux_filepath = String::new();
            linux_filepath.push_str("/mnt/");
            linux_filepath.push_str(&file[0..1].to_lowercase());
            linux_filepath.push_str(&file[2..].replace('\\', "/"));
            cmd.push_str(&linux_filepath);
        } else if !file.starts_with("/") && !file.starts_with("~") {
            let dir = tmux!["display", "-p", "#{pane_current_path}"];
            cmd.push_str(&format!("{dir}/{file}"));
        } else {
            cmd.push_str(&file);
        }
        if let Some(line) = line { cmd.push_str(&format!(" | {line}")); }
        if let Some(col) = col { cmd.push_str(&format!(" | normal {col}|")); }
        let req = req!("nvim_exec", cmd, 0);
        let resp: Value = rpc(&mut nvim_conn, &req);
        // dbg!(resp);

        tmux!["select-pane", "-t", &nvim_pane];
    } else {
        panic!("no command")
    }
}

fn look_for_server_file(dir_path: &str, my_sess_name: &str, sess_by_pane_id: &HashMap<&str, &str>) -> Option<(UnixStream, String)> {
    let Ok(entries) = std::fs::read_dir(dir_path) else { return None; };
    for dir_entry in entries {
        // dbg!(&dir_entry);
        let Ok(dir_entry) = dir_entry else { continue; };

        let file_path = dir_entry.path();
        let file_name = file_path.file_name().unwrap();
        let file_name = file_name.to_str().unwrap();
        // dbg!(file_name);
        if !file_name.starts_with("nvim") { continue; }
        if !file_name.ends_with(".0") { continue; }

        let sock_path = file_path;
        let res = UnixStream::connect(&sock_path);
        let Ok(mut conn) = res else { continue; };

        let req = Req {
            msg_type: MSG_TYPE_REQ,
            sync: 420,
            proc: "nvim_eval",
            args: vec!["$TMUX_PANE".into()],
        };

        let nvim_pane: String = rpc(&mut conn, &req);
        let Some(nvim_sess) = sess_by_pane_id.get(&*nvim_pane) else {
            eprintln!("'{}' is not a known tmux pane", nvim_pane);
            continue;
        };

        if *nvim_sess == my_sess_name {
            println!("socket: {}", sock_path.display());
            return Some((conn, nvim_pane));
        }
    }

    None
}

#[track_caller]
fn rpc<R>(conn: &mut UnixStream, req: &Req) -> R
where
    for<'a> R: serde::Deserialize<'a>,
{
    conn.write_all(&rmp_serde::to_vec(&req).unwrap()).unwrap();
    let mut data = vec![0_u8; 1024 * 1024];
    let mut n_bytes_received = 0;
    let response: Resp<Option<R>> = loop {
        n_bytes_received += conn.read(&mut data).unwrap();
        let data_so_far = &data[0..n_bytes_received];
        let res = rmp_serde::from_slice(data_so_far);
        match res {
            Ok(resp) => { break resp; }
            Err(rmp_serde::decode::Error::InvalidDataRead(_) | rmp_serde::decode::Error::InvalidMarkerRead(_)) => {
                // ignore
                continue;
            }
            Err(e) => {
                panic!("ERROR: {e}\ngot: {:?}\nraw: {:#02x?}", rmp_serde::from_slice::<rmpv::Value>(data_so_far).unwrap(), data_so_far);
            }
        }
    };
    if let Some((code, msg)) = response.err {
        panic!("{code}: {msg}");
    }
    response.value.unwrap()
}

// <file>:<line>:<col> | or <file>:<line>,<col> like in Jai
fn is_file_loc_char(c: char) -> bool {
    c.is_alphanumeric() || c == '-' || c == '_' || c == '/' || c == ':' || c == '.' || c == '~' || c == ','
}
