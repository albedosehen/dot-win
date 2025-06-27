# DotWin Architecture Guide

## Overview

DotWin implements a sophisticated declarative configuration management system for Windows, featuring a multi-layered architecture that bridges rich PowerShell configurations with a robust class-based execution engine.

## Architectural Principles

### 1. Declarative Configuration

- **Intent-Based**: Users declare desired state, not implementation steps
- **Idempotent**: Safe to run multiple times, only applies necessary changes
- **Composable**: Configurations can be combined and extended
- **Testable**: Built-in validation and testing capabilities

### 2. Rich Configuration System

- **PowerShell-Native**: Leverage full PowerShell capabilities in configurations
- **Type-Safe**: Strong typing through PowerShell classes
- **Extensible**: Plugin architecture for custom configuration types
- **Discoverable**: Automatic discovery of available configurations

### 3. Intelligent Automation

- **System-Aware**: Deep understanding of system state and capabilities
- **Recommendation-Driven**: ML-based recommendations for optimal configurations
- **Progress-Aware**: Comprehensive progress tracking and reporting
- **Error-Resilient**: Graceful error handling and recovery

## System Architecture

### High-Level Architecture

```mermaid
graph TB
    subgraph "User Interface Layer"
        A[PowerShell Functions]
        B[Configuration Files]
        C[Command Line Interface]
    end
    
    subgraph "Configuration Layer"
        D[Rich Config Files<br/>config/*.ps1]
        E[JSON Configurations<br/>examples/*.json]
        F[Configuration Bridge]
    end
    
    subgraph "Core Engine"
        G[DotWin Classes<br/>Classes.ps1]
        H[Execution Engine]
        I[Progress System]
    end
    
    subgraph "System Integration"
        J[Package Managers<br/>Winget, Chocolatey, Scoop]
        K[Windows APIs<br/>Registry, WMI, CIM]
        L[External Tools<br/>Git, Terminal, WSL]
    end
    
    A --> F
    B --> D
    C --> A
    D --> F
    E --> F
    F --> G
    G --> H
    H --> I
    H --> J
    H --> K
    H --> L

    style D fill:#e1f5fe
    style F fill:#e8f5e8
    style G fill:#f3e5f5
    style H fill:#fff3e0
```

### Component Architecture

```mermaid
graph LR
    subgraph "Configuration Sources"
        A1[config/Packages.ps1<br/>600+ lines]
        A2[config/Terminal.ps1<br/>664+ lines]
        A3[config/Profile.ps1<br/>574+ lines]
        A4[config/Tools.ps1<br/>590+ lines]
        A5[config/WSL.ps1<br/>215+ lines]
    end
    
    subgraph "Configuration Bridge"
        B1[ConvertTo-DotWinConfiguration]
        B2[Configuration Registry]
        B3[Validation Engine]
    end
    
    subgraph "Core Functions"
        C1[Invoke-DotWinConfiguration]
        C2[Install-Packages]
        C3[Set-TerminalProfile]
        C4[Get-DotWinRecommendations]
        C5[Export-DotWinConfiguration]
    end
    
    subgraph "Class Hierarchy"
        D1[DotWinConfigurationItem]
        D2[DotWinWingetPackage]
        D3[DotWinWindowsTerminal]
        D4[DotWinSystemProfiler]
        D5[DotWinProgressContext]
    end
    
    A1 --> B1
    A2 --> B1
    A3 --> B1
    A4 --> B1
    A5 --> B1
    
    B1 --> C1
    B2 --> C1
    B3 --> C1
    
    C1 --> D1
    C2 --> D2
    C3 --> D3
    C4 --> D4
    C5 --> D1
    
    style A1 fill:#e1f5fe
    style A2 fill:#e1f5fe
    style A3 fill:#e1f5fe
    style A4 fill:#e1f5fe
    style A5 fill:#e1f5fe
    style B1 fill:#e8f5e8
    style B2 fill:#e8f5e8
    style B3 fill:#e8f5e8
```

## Core Components

### 1. Rich Configuration System

#### Configuration Files Structure

```text
config/
├── Packages.ps1      # Package definitions and categories
├── Terminal.ps1      # Terminal themes and profiles
├── Profile.ps1       # PowerShell profile templates
├── Tools.ps1         # System tools and optimizations
└── WSL.ps1          # WSL distribution configurations
```

#### Configuration File Architecture

Each configuration file follows a consistent pattern:

```powershell
# Category-based organization
function Get-DevelopmentPackages { ... }
function Get-ProductivityPackages { ... }

# Template builders
function Get-SolarizedDarkTheme { ... }
function Get-CampbellTheme { ... }

# Helper functions
function Install-PackageCategory { ... }
function Test-PackageInstalled { ... }
```

### 2. Class Hierarchy

#### Base Classes

**DotWinConfigurationItem** - Foundation for all configuration items

```powershell
class DotWinConfigurationItem {
    [string] $Name
    [string] $Type
    [bool] $Enabled
    [hashtable] $Properties

    [bool] Test()           # Check if item is in desired state
    [void] Apply()          # Apply the configuration
    [object] GetCurrentState()  # Get current system state
}
```

**DotWinExecutionResult** - Standardized execution results

```powershell
class DotWinExecutionResult {
    [bool] $Success
    [string] $Message
    [timespan] $Duration
    [hashtable] $Changes
    [hashtable] $Metadata
}
```

#### Specialized Classes

##### Package Management

- `DotWinWingetPackage` - Windows Package Manager integration
- `DotWinChocolateyPackage` - Chocolatey package management
- `DotWinScoopPackage` - Scoop package management

##### System Configuration

- `DotWinWindowsTerminal` - Terminal configuration management
- `DotWinPowerShellProfile` - PowerShell profile management
- `DotWinRegistryConfiguration` - Registry setting management
- `DotWinWindowsFeature` - Windows feature management

##### Intelligence & Profiling

- `DotWinSystemProfiler` - System analysis and profiling
- `DotWinRecommendationEngine` - ML-based recommendations
- `DotWinHardwareProfile` - Hardware detection and analysis
- `DotWinSoftwareProfile` - Software inventory and analysis

### 3. Configuration Bridge Layer

The configuration bridge translates between rich PowerShell configurations and the JSON schema expected by core functions.

#### Bridge Architecture

```mermaid
sequenceDiagram
    participant U as User
    participant F as Function
    participant B as Bridge
    participant R as Rich Config
    participant C as Classes
    
    U->>F: Call with category/theme
    F->>B: ConvertTo-DotWinConfiguration
    B->>R: Load config/*.ps1
    R->>R: Execute PowerShell functions
    R-->>B: Return configuration objects
    B->>C: Create DotWinConfiguration
    C-->>B: Return JSON schema object
    B-->>F: Return configuration
    F->>F: Apply configuration
```

#### Bridge Functions

- **`ConvertTo-DotWinConfiguration`** - Main conversion function
- **`Get-DotWinConfigurationRegistry`** - Configuration discovery
- **`Test-DotWinConfiguration`** - Configuration validation
- **`Resolve-DotWinConfigurationDependencies`** - Dependency resolution

### 4. Progress and Execution System

#### Progress Architecture

```mermaid
graph TD
    A[Master Progress Context] --> B[Function Progress]
    B --> C[Item Progress]
    C --> D[Sub-operation Progress]
    
    A --> E[Progress Stack Manager]
    E --> F[Progress Coordination]
    F --> G[Console Output]
    F --> H[Log Files]
    F --> I[Event System]
    
    style A fill:#e8f5e8
    style E fill:#fff3e0
    style F fill:#f3e5f5
```

#### Progress Classes

- **`DotWinProgressContext`** - Individual progress tracking
- **`DotWinProgressStackManager`** - Hierarchical progress management
- **`DotWinProgressCoordinator`** - Multi-threaded progress coordination

### 5. Intelligence and Recommendation System

#### System Profiling Architecture

```mermaid
graph LR
    A[System Profiling] --> B[Hardware Analysis]
    A --> C[Software Inventory]
    A --> D[User Behavior Analysis]
    A --> E[Performance Metrics]
    
    B --> F[Recommendation Engine]
    C --> F
    D --> F
    E --> F
    
    F --> G[Rule-Based Recommendations]
    F --> H[ML-Based Recommendations]
    F --> I[Conflict Resolution]
    
    G --> J[Prioritized Recommendations]
    H --> J
    I --> J
    
    style A fill:#e1f5fe
    style F fill:#e8f5e8
    style J fill:#c8e6c9
```

#### Intelligence Components

- **Hardware Profiling**: CPU, memory, storage, and peripheral detection
- **Software Analysis**: Installed packages, running services, and usage patterns
- **User Behavior**: Command history, preference analysis, and workflow detection
- **Performance Metrics**: System performance scoring and optimization potential

## Data Flow Patterns

### 1. Configuration Application Flow

```mermaid
sequenceDiagram
    participant U as User
    participant IC as Invoke-DotWinConfiguration
    participant CB as Configuration Bridge
    participant CI as Configuration Item
    participant S as System
    
    U->>IC: Apply configuration
    IC->>CB: Load and convert configuration
    CB-->>IC: Return DotWinConfiguration
    
    loop For each configuration item
        IC->>CI: Test current state
        CI->>S: Query system state
        S-->>CI: Return current state
        CI-->>IC: Return test result

        alt Needs configuration
            IC->>CI: Apply configuration
            CI->>S: Make system changes
            S-->>CI: Confirm changes
            CI-->>IC: Return success
        else Already configured
            IC->>IC: Skip item
        end
    end
    
    IC-->>U: Return execution results
```

### 2. Package Installation Flow

```mermaid
sequenceDiagram
    participant U as User
    participant IP as Install-Packages
    participant PC as Package Config
    participant PM as Package Manager
    participant S as System
    
    U->>IP: Install packages by category
    IP->>PC: Load category from config/Packages.ps1
    PC->>PC: Execute Get-CategoryPackages function
    PC-->>IP: Return package list
    
    loop For each package
        IP->>PM: Check if installed
        PM->>S: Query installed packages
        S-->>PM: Return package status
        PM-->>IP: Return installation status

        alt Not installed
            IP->>PM: Install package
            PM->>S: Download and install
            S-->>PM: Installation complete
            PM-->>IP: Return success
        else Already installed
            IP->>IP: Skip package
        end
    end
    
    IP-->>U: Return installation results
```

### 3. Terminal Configuration Flow

```mermaid
sequenceDiagram
    participant U as User
    participant STP as Set-TerminalProfile
    participant TC as Terminal Config
    parameter WT as Windows Terminal
    
    U->>STP: Configure terminal with theme
    STP->>TC: Load theme from config/Terminal.ps1
    TC->>TC: Execute theme builder function
    TC-->>STP: Return theme configuration
    
    STP->>STP: Create DotWinWindowsTerminal object
    STP->>WT: Read current settings
    WT-->>STP: Return current configuration
    
    STP->>STP: Merge configurations
    STP->>WT: Write new settings
    WT-->>STP: Confirm settings applied

    STP-->>U: Return configuration result
```

## Integration Patterns

### 1. Rich Configuration Integration

#### Current State (Partial Integration)

```mermaid
graph LR
    A[Install-Packages] --> B[config/Packages.ps1]
    C[Set-TerminalProfile] -.-> D[Hardcoded Configs]
    E[Invoke-DotWinConfiguration] -.-> F[JSON Only]

    style B fill:#c8e6c9
    style D fill:#ffebee
    style F fill:#ffebee
```

#### Target State (Full Integration)

```mermaid
graph LR
    A[Install-Packages] --> B[config/Packages.ps1]
    C[Set-TerminalProfile] --> D[config/Terminal.ps1]
    E[Invoke-DotWinConfiguration] --> F[Configuration Bridge]
    G[Set-PowerShellProfile] --> H[config/Profile.ps1]

    F --> B
    F --> D
    F --> H
    F --> I[config/Tools.ps1]
    F --> J[config/WSL.ps1]

    style B fill:#c8e6c9
    style D fill:#c8e6c9
    style F fill:#e8f5e8
    style H fill:#c8e6c9
    style I fill:#c8e6c9
    style J fill:#c8e6c9
```

### 2. Error Handling and Recovery

#### Error Handling Architecture

```mermaid
graph TD
    A[Function Execution] --> B{Error Occurred?}
    B -->|No| C[Continue Execution]
    B -->|Yes| D[Error Classification]

    D --> E{Error Type?}
    E -->|Recoverable| F[Retry Logic]
    E -->|Configuration| G[Validation Error]
    E -->|System| H[System Error]
    E -->|Critical| I[Fatal Error]

    F --> J[Exponential Backoff]
    J --> K{Retry Successful?}
    K -->|Yes| C
    K -->|No| L[Log and Continue]

    G --> M[User Feedback]
    H --> N[System Diagnostics]
    I --> O[Graceful Shutdown]

    style D fill:#fff3e0
    style F fill:#e8f5e8
    style I fill:#ffebee
```

### 3. Performance Optimization

#### Parallel Processing Architecture

```mermaid
graph TB
    A[Main Thread] --> B{Parallel Capable?}
    B -->|Yes| C[PowerShell 7+ Parallel]
    B -->|No| D[Sequential Processing]

    C --> E[Runspace Pool]
    E --> F[Task 1: Hardware Profiling]
    E --> G[Task 2: Software Analysis]
    E --> H[Task 3: User Profiling]

    F --> I[Result Aggregation]
    G --> I
    H --> I

    D --> J[Sequential Tasks]
    J --> I

    I --> K[Final Result]

    style C fill:#e8f5e8
    style E fill:#c8e6c9
    style D fill:#fff3e0
```

## Security Architecture

### 1. Execution Security

#### Security Layers

```mermaid
graph TD
    A[User Input] --> B[Input Validation]
    B --> C[Configuration Validation]
    C --> D[Privilege Checking]
    D --> E[Execution Sandboxing]
    E --> F[System Changes]
    F --> G[Change Auditing]

    H[Security Policies] --> B
    H --> C
    H --> D
    H --> E

    I[Audit Logs] --> G
    J[Event System] --> G

    style H fill:#f3e5f5
    style I fill:#e1f5fe
    style J fill:#e1f5fe
```

### 2. Configuration Security

#### Secure Configuration Handling

- **Input Sanitization**: All user inputs validated and sanitized
- **Code Injection Prevention**: PowerShell execution context isolation
- **Privilege Escalation Protection**: Minimal privilege principle
- **Audit Trail**: Comprehensive logging of all system changes

## Extensibility Architecture

### 1. Plugin System

#### Plugin Architecture

```mermaid
graph LR
    A[Plugin Interface] --> B[Configuration Plugins]
    A --> C[Package Manager Plugins]
    A --> D[System Integration Plugins]
    A --> E[Intelligence Plugins]

    B --> F[Custom Config Types]
    C --> G[New Package Sources]
    D --> H[External Tool Integration]
    E --> I[Custom Recommendation Engines]

    style A fill:#f3e5f5
    style F fill:#e8f5e8
    style G fill:#e8f5e8
    style H fill:#e8f5e8
    style I fill:#e8f5e8
```

### 2. Extension Points

#### Key Extension Points

- **Configuration Types**: Custom configuration item types
- **Package Sources**: Additional package manager support
- **Recommendation Engines**: Custom recommendation algorithms
- **Progress Providers**: Custom progress tracking implementations
- **Validation Rules**: Custom configuration validation logic

## Performance Characteristics

### 1. Scalability Metrics

| Component | Small System | Medium System | Large System |
|-----------|--------------|---------------|--------------|
| Configuration Items | < 50 | 50-200 | 200+ |
| Package Installation | < 10 packages | 10-50 packages | 50+ packages |
| System Profiling | < 5 seconds | 5-15 seconds | 15+ seconds |
| Memory Usage | < 100MB | 100-300MB | 300+ MB |

### 2. Performance Optimizations

#### Optimization Strategies

- **Lazy Loading**: Configuration files loaded on demand
- **Caching**: Frequently accessed data cached in memory
- **Parallel Processing**: Multi-threaded operations where possible
- **Incremental Updates**: Only apply necessary changes
- **Progress Streaming**: Real-time progress updates

## Future Architecture Considerations

### 1. Cloud Integration

- **Configuration Sync**: Cloud-based configuration synchronization
- **Remote Management**: Centralized configuration management
- **Telemetry**: Anonymous usage analytics and improvement insights

### 2. Advanced Intelligence

- **Machine Learning**: Enhanced recommendation algorithms
- **Predictive Analysis**: Proactive system optimization suggestions
- **Behavioral Learning**: Adaptive configurations based on usage patterns

### 3. Enterprise Features

- **Group Policy Integration**: Enterprise policy compliance
- **Centralized Deployment**: Mass deployment capabilities
- **Compliance Reporting**: Automated compliance verification

---

This architecture provides a solid foundation for declarative Windows configuration management while maintaining flexibility for future enhancements and enterprise requirements.
