use thiserror::Error;

pub type BrewweryResult<T> = Result<T, BrewweryError>;

#[derive(Debug, Error)]
pub enum BrewweryError {
    #[error("Homebrew executable was not found")]
    HomebrewNotFound,
    #[error("command failed: {0}")]
    CommandFailed(String),
    #[error("unable to parse Homebrew output: {0}")]
    ParseFailed(String),
    #[error("invalid package name: {0}")]
    InvalidPackageName(String),
    #[error("invalid service name: {0}")]
    InvalidServiceName(String),
}
