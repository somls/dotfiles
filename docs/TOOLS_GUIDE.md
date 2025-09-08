# Tools Guide

This guide covers all the essential tools included in this dotfiles configuration, organized by category with practical usage examples and integration tips.

## 核心开发工具 (Essential Tools)

### Git
**Purpose**: Version control system
**Usage**:
```bash
git status                    # Check repository status
git add .                     # Stage all changes
git commit -m "message"       # Commit with message
git push origin main          # Push to remote
git pull                      # Pull latest changes
```

### Ripgrep (rg)
**Purpose**: Ultra-fast text search tool
**Usage**:
```bash
rg "pattern"                  # Search for pattern in current directory
rg -i "pattern"               # Case-insensitive search
rg -t py "function"           # Search only in Python files
rg -A 3 -B 3 "pattern"        # Show 3 lines before/after match
```

### Zoxide (z)
**Purpose**: Smart directory navigation
**Usage**:
```bash
z project                     # Jump to directory containing "project"
z foo bar                     # Jump to directory matching "foo" and "bar"
zi                           # Interactive directory selection
```

### FZF
**Purpose**: Fuzzy finder for command line
**Usage**:
```bash
fzf                          # Interactive file finder
git log --oneline | fzf      # Fuzzy search git commits
history | fzf                # Search command history
```

### Bat
**Purpose**: Enhanced cat with syntax highlighting
**Usage**:
```bash
bat file.py                  # View file with syntax highlighting
bat -n file.js               # Show line numbers
bat --style=plain file.md    # Plain output without decorations
```

### Fd
**Purpose**: Fast and user-friendly alternative to find
**Usage**:
```bash
fd pattern                   # Find files/directories matching pattern
fd -e py                     # Find all Python files
fd -t f pattern              # Find only files (not directories)
fd -H pattern                # Include hidden files
```

### JQ
**Purpose**: JSON processor and formatter
**Usage**:
```bash
echo '{"name":"John"}' | jq  # Pretty print JSON
jq '.name' data.json         # Extract specific field
jq '.[] | select(.age > 30)' # Filter array elements
```

### Neovim
**Purpose**: Modern Vim-based text editor
**Key Features**:
- LSP support for intelligent code completion
- Tree-sitter for better syntax highlighting
- Lua configuration for extensibility
- Built-in terminal emulator

### Starship
**Purpose**: Cross-shell prompt customization
**Features**:
- Git status integration
- Language version detection
- Execution time display
- Custom modules support

### Visual Studio Code
**Purpose**: Feature-rich code editor
**Integration**: Works seamlessly with other tools in this setup

### Sudo
**Purpose**: Execute commands with elevated privileges
**Usage**:
```bash
sudo command                 # Run command as administrator
```

### Curl
**Purpose**: Data transfer tool
**Usage**:
```bash
curl https://api.example.com # GET request
curl -X POST -d "data" url   # POST request
curl -o file.zip url         # Download file
```

### 7zip
**Purpose**: File archiver with high compression ratio
**Usage**:
```bash
7z a archive.7z files/       # Create archive
7z x archive.7z              # Extract archive
```

## 开发工具 (Development Tools)

### ShellCheck
**Purpose**: Static analysis tool for shell scripts
**Usage**:
```bash
shellcheck script.sh         # Check shell script for issues
shellcheck -f gcc script.sh  # GCC-style output format
```

### GitHub CLI (gh)
**Purpose**: GitHub operations from command line
**Usage**:
```bash
gh repo clone user/repo      # Clone repository
gh pr create                 # Create pull request
gh issue list                # List issues
gh workflow run              # Trigger workflow
```

### Node.js
**Purpose**: JavaScript runtime environment
**Package Management**:
```bash
npm install package          # Install package locally
npm install -g package       # Install package globally
npx command                  # Execute package without installing
```

### Python
**Purpose**: Programming language and runtime
**Package Management**:
```bash
pip install package          # Install Python package
python -m venv env           # Create virtual environment
pip freeze > requirements.txt # Export dependencies
```

## Git增强工具 (Git Enhanced Tools)

### Lazygit
**Purpose**: Terminal UI for Git operations
**Features**:
- Visual representation of Git repository
- Interactive staging and committing
- Branch management
- Merge conflict resolution
- Stash management

**Key Shortcuts**:
- `Space`: Stage/unstage files
- `c`: Commit
- `P`: Push
- `p`: Pull
- `b`: Switch branches
- `m`: Merge

## Tool Integration Examples

### Combined Workflows

**File Search and Edit**:
```bash
# Find and edit files with fzf and neovim
nvim $(fd -t f | fzf)

# Search content and edit matching files
rg -l "pattern" | fzf | xargs nvim
```

**Git Workflow**:
```bash
# Interactive git operations
lazygit

# Quick commit with fuzzy file selection
git add $(git status --porcelain | fzf -m | awk '{print $2}')
```

**Directory Navigation**:
```bash
# Jump to project and open editor
z project && code .

# Navigate and search in one command
cd $(fd -t d | fzf) && rg "pattern"
```

## Configuration Tips

### Shell Integration
Most tools integrate automatically with your shell configuration. Key integrations:

- **Zoxide**: Adds `z` command for smart navigation
- **FZF**: Provides `Ctrl+R` for history search, `Ctrl+T` for file search
- **Starship**: Customizes your prompt with contextual information

### Editor Integration
- **Neovim**: Configured with LSP support for the installed languages
- **VSCode**: Extensions automatically detect and use command-line tools

### Performance Tips
- Use `bat` instead of `cat` for syntax highlighting
- Use `fd` instead of `find` for faster file searches
- Use `rg` instead of `grep` for faster text searches
- Use `z` instead of `cd` for smarter navigation

## Troubleshooting

### Common Issues
1. **Tool not found**: Ensure Scoop is in your PATH
2. **Slow performance**: Check if tools are using correct configuration files
3. **Integration issues**: Restart your shell after installation

### Getting Help
```bash
tool --help                  # Most tools provide built-in help
man tool                     # Manual pages (where available)
tool --version               # Check installed version
```

## Next Steps

After installing these tools:
1. Customize Starship prompt in `starship/starship.toml`
2. Configure Neovim plugins in `neovim/init.lua`
3. Set up Git configuration in `git/gitconfig`
4. Explore tool-specific configuration files in their respective directories

For more detailed configuration of individual tools, refer to their respective documentation in the project's subdirectories.