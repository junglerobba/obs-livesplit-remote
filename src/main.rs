use anyhow::Result;
use clap::Parser;
use console::{Key, Term};
use core::fmt;
use obws::Client;

#[derive(clap::ValueEnum, Clone, Debug)]
enum LivesplitAction {
    Split,
    Reset,
    Undo,
    Skip,
    Pause,
    Resume,
    Listen,
}

impl TryFrom<Key> for LivesplitAction {
    type Error = anyhow::Error;
    fn try_from(key: Key) -> Result<LivesplitAction, anyhow::Error> {
        match key {
            Key::ArrowRight => Ok(LivesplitAction::Split),
            Key::ArrowDown => Ok(LivesplitAction::Skip),
            Key::ArrowUp => Ok(LivesplitAction::Undo),
            Key::ArrowLeft => Ok(LivesplitAction::Pause),
            Key::Enter => Ok(LivesplitAction::Reset),
            _ => Err(anyhow::Error::msg("message")),
        }
    }
}

impl fmt::Display for LivesplitAction {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            LivesplitAction::Split => write!(f, "hotkey_split"),
            LivesplitAction::Reset => write!(f, "hotkey_reset"),
            LivesplitAction::Undo => write!(f, "hotkey_undo"),
            LivesplitAction::Skip => write!(f, "hotkey_skip"),
            LivesplitAction::Pause => write!(f, "hotkey_pause"),
            LivesplitAction::Resume => write!(f, "hotkey_resume"),
            LivesplitAction::Listen => panic!("not a hotkey"),
        }
    }
}

#[derive(Parser, Debug)]
struct Args {
    #[clap(short = 'H', long, default_value = "localhost")]
    host: String,
    #[clap(short, long, default_value = "4444")]
    port: u16,
    #[clap(short = 'P', long)]
    password: Option<String>,
    #[clap(value_enum)]
    action: LivesplitAction,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    let client = Client::connect(args.host, args.port, args.password).await?;

    match args.action {
        LivesplitAction::Listen => listen(client).await,
        _ => {
            let action = format!("{}", args.action);
            client.hotkeys().trigger_by_name(&action).await?;
            Ok(())
        }
    }
}

async fn listen(client: Client) -> Result<()> {
    println!("Press q to quit");
    let stdout = Term::buffered_stdout();
    loop {
        match stdout.read_key() {
            Ok(console::Key::Char('q')) => return Ok(()),
            Ok(key) => {
                let action = if let Ok(key) = LivesplitAction::try_from(key) {
                    key
                } else {
                    continue;
                };
                let action = format!("{}", action);
                client.hotkeys().trigger_by_name(&action).await?;
            }
            _ => continue,
        }
    }
}
