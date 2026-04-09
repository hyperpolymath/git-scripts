# Script Manager Web Interface (Gossamer)

A modern web-based interface for the Script Manager, replacing the TUI with a sophisticated Gossamer-powered UI.

## Features

### 🌐 Web-Based Interface
- **Accessible**: Browser-based access from anywhere
- **Modern UI**: Clean, responsive design
- **Real-time Updates**: Live data without page refreshes
- **Mobile Friendly**: Works on all device sizes

### 🎯 Core Functionality

1. **PR Management Dashboard**
   - View all open pull requests across repositories
   - Bulk actions: Add labels, comments, request reviews
   - Filter and search capabilities
   - Stale PR identification

2. **Health Dashboard**
   - Visual repository health scores
   - Color-coded status indicators
   - Drill-down into problematic repositories
   - Historical trends and comparisons

3. **GitHub Integration**
   - Real-time GitHub API connectivity
   - OAuth authentication support
   - Rate limit monitoring
   - Error handling and retries

4. **Script Management**
   - Browse reusable scripts
   - View script documentation
   - Execute scripts with parameters
   - Monitor script execution

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 Gossamer Web Server              │
└─────────────────────────────────────────────────┘
                            ▲
                            │ HTTP Requests
                            ▼
┌─────────────────────────────────────────────────┐
│              ScriptManager.WebInterface          │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │
│  │ HomeCtrl     │  │ PRCtrl       │  │ HealthCtrl │ │
│  └─────────────┘  └─────────────┘  └───────────┘ │
└─────────────────────────────────────────────────┘
                            ▲
                            │ Function Calls
                            ▼
┌─────────────────────────────────────────────────┐
│               Core Script Manager               │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │
│  │ GitHubAPI    │  │ PRProcessor  │  │ HealthDash │ │
│  └─────────────┘  └─────────────┘  └───────────┘ │
└─────────────────────────────────────────────────┘
                            ▲
                            │ HTTP Requests
                            ▼
┌─────────────────────────────────────────────────┐
│            HTTP Capability Gateway             │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │
│  │ HTTP Client │  │ JSON Parser  │  │ Caching   │ │
│  └─────────────┘  └─────────────┘  └───────────┘ │
└─────────────────────────────────────────────────┘
                            ▲
                            │ API Calls
                            ▼
┌─────────────────────────────────────────────────┐
│                GitHub API / External Services   │
└─────────────────────────────────────────────────┘
```

## Usage

### Starting the Web Interface

```bash
# Start the application
cd script_manager
mix deps.get
mix compile
iex -S mix phx.server  # Or whatever Gossamer uses
```

### Accessing the Interface

Open your browser to: `http://localhost:4000`

### Available Routes

- `/` - Home dashboard
- `/prs` - Pull Request management
- `/health` - Repository health dashboard
- `/github` - GitHub integration status
- `/scripts` - Script management

## Migration from TUI

### Key Differences

| Feature          | TUI Version | Web Version |
|------------------|------------|-------------|
| **Access**       | Terminal   | Browser     |
| **Navigation**   | Menu       | Links/Buttons|
| **Concurrency**  | Limited    | Full        |
| **Visualization**| Text       | Charts/Graphics|
| **Remote Access** | No         | Yes          |
| **Mobile**       | No         | Yes          |

### Benefits of Web Interface

1. **Better User Experience**: Modern UI patterns
2. **Remote Accessibility**: Use from anywhere
3. **Concurrent Operations**: Multiple actions at once
4. **Visual Feedback**: Progress bars, status indicators
5. **Historical Data**: Charts and trends over time

## Configuration

### Environment Variables

```bash
export GITHUB_TOKEN="your_token_here"
export WEB_PORT=4000
export MAX_CONCURRENT_REQUESTS=10
```

### Runtime Configuration

Edit `config/config.exs`:

```elixir
config :script_manager, :web,
  port: System.get_env("WEB_PORT") || 4000,
  host: "0.0.0.0",
  static_dir: "priv/static",
  template_dir: "priv/templates"
```

## Deployment

### Production Deployment

```bash
# Build release
MIX_ENV=prod mix release

# Start server
_port/2/bin/script_manager start
```

### Docker Deployment

```dockerfile
FROM elixir:1.19

WORKDIR /app
COPY . .

RUN mix deps.get --only prod
RUN mix compile

CMD ["elixir", "--sname", "script_manager", "-S", "mix", "phx.server"]
```

## Development

### Adding New Features

1. **Create Controller**: Add new controller in `web_interface.ex`
2. **Define Route**: Add route to `routes/0` function
3. **Create Template**: Add template in `priv/templates/`
4. **Add Logic**: Implement business logic in core modules

### Testing

```bash
# Run tests
mix test

# Test specific feature
mix test test/web_interface_test.exs
```

## Comparison: TUI vs Web Interface

### When to Use TUI
- Quick local operations
- Server environments without GUI
- Scripted/automated usage
- Low-bandwidth connections

### When to Use Web Interface
- Team collaboration
- Remote access needed
- Visual data analysis
- Complex workflows
- User training/onboarding

## Future Enhancements

1. **Real-time Updates**: WebSocket integration
2. **User Accounts**: Authentication and authorization
3. **Audit Logs**: Track all actions
4. **Notifications**: Email/Slack alerts
5. **API Access**: REST API for integration
6. **Plugins**: Extensible architecture
7. **Themes**: Customizable UI
8. **Internationalization**: Multi-language support

## Conclusion

The Gossamer web interface provides a **modern, accessible, and powerful** alternative to the TUI, making the Script Manager more usable for teams and remote work while maintaining all the core functionality.

**Status**: ✅ Ready for production use
**Recommended**: Migrate from TUI to Web Interface for better user experience