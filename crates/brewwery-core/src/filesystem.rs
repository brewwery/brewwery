pub fn home_dir() -> Option<String> {
    std::env::var("HOME").ok()
}
