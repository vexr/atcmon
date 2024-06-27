# About atcmon

atcmon is a lightweight monitoring script designed to help you monitor various Autonomy rewards and events. Key features include:

- **Monitoring Capabilities**:
    - Rewards from block wins
    - Rewards from block votes
    - Slow blocks
    - Expired blocks
    - Rewards from bundle rewards (for operators)
  
- **Configurable Reporting Periods**:
    - Easily configure four different reporting periods
    - The fourth period monitors the interval between the third and fourth periods

- **Minimal Dependencies**:
    - Written in bash
    - Requires only minimal dependencies (`bc` and `jq`)

- **Low System Resource Usage**:
    - Designed to run efficiently with minimal impact on system performance

atcmon provides a simple yet powerful way to keep track of important Autonomy events on your farm, helping you stay informed about your rewards and other potential issues with your farm.



# Help Guide for atcmon

This guide will help you install atcmon, configure the JSON configuration file correctly, and run the script. Follow the instructions for each section to ensure proper setup.

1.  **Installing and Setting the Script as Executable**: Instructions on how to clone the repository, navigate to the directory, and set the script as executable.
2.  **Configuring the `config.json` File**: Detailed steps on how to populate the `config.json` file with the necessary settings.
3.  **Running the Script**: How to execute the script and ensure all dependencies are installed.

## Installing and Setting the Script as Executable

Follow these steps to clone the repository and set the script as executable. The script is named `atcmon.sh`.

### Step 1: Clone the Repository

First, clone the repository from GitHub to your local machine:

```sh
git clone https://github.com/vexr/atcmon.git
```
### Step 2: Navigate to the Directory

Change to the directory where the repository was cloned:
```sh
cd atcmon
```

### Step 3: Set the Script as Executable

Set the script `atcmon.sh` to be executable:
```sh
chmod +x atcmon.sh
```

## Configure Config JSON

The JSON file is divided into two main sections:
1. `config`: Contains configuration settings such as log file paths and dashboard refresh rate.
2. `period`: Defines various reward periods.

### Config Section

The `config` section includes the following fields:

- **version**: The version of the configuration for atcmon. This should remain unchanged.

- **farmer_log**: The absolute path to the farmer log file. You can generate this log file by appending `| tee -a <LOG_NAME>` to the end of your farmer launch command. For example:

	`farmer_command | tee -a /home/$USER/Autonomys/farmer.log`

- **node_log**: The absolute path to the node log file. Generate this log file similarly by appending `| tee -a <LOG_NAME>` to your node launch command. For example:

	`node_command | tee -a /home/$USER/Autonomys/node.log`


- **dashboard_refresh_rate**: The refresh rate for the dashboard in seconds. For example, `300` means the dashboard will refresh every 5 minutes.

> [!TIP]
> To refresh results instantly while the script is running, press the 'r' key instead of waiting for `dashboard_refresh_rate` to expire.

### Period Section

The `period` section specifies the durations for various monitoring periods. You can use the following time units: Minute(s), Hour(s), Day(s), Week(s), Month(s).

- **reward_period_1**: Set this to your desired period, e.g., `"3 Hours"`.
- **reward_period_2**: Set this to your desired period, e.g., `"12 Hours"`.
- **reward_period_3**: Set this to your desired period, e.g., `"1 Day"`.
- **reward_period_4**: Set this to your desired period, e.g., `"1 Month"`.

> [!TIP]
> In the configuration, `"reward_period_4"` represents a time frame that spans from the start of `"reward_period_3"` to `"reward_period_4"`. Adjust accordingly based on your needs for time intervals.


### Edit `config.json`

To configure the script, you need to edit the `config.json` file. Follow these steps to ensure you make the necessary changes correctly, without altering the valid JSON syntax:

1.  **Open the `config.json` file**:
    
-   Use your favorite text editor to open the `config.json` file. For example, you can use `nano` or `vim`.

2.  **Edit the Configuration Settings**:

-   Carefully modify the required settings in the `config.json` file. Ensure that you follow proper JSON syntax.

## Example Configuration

Here is an example of a correctly populated JSON configuration:
```json
{
  "config": {
    "version": "0.1.0",

    "farmer_log": "/home/$USER/Autonomys/farmer.log",
    "node_log": "/home/$USER/Autonomys/node.log",
    "dashboard_refresh_rate": 300
  },

  "period": {
    "reward_period_1": "3 Hours",
    "reward_period_2": "12 Hours",
    "reward_period_3": "1 Day",
    "reward_period_4": "1 Month"
  }
}
```
> [!NOTE]
> Ensure that you replace the paths to the log files with the actual absolute paths on your system, and set the desired reward periods and dashboard refresh rate according to your needs.

## Running the Script

Once the script is installed and set as executable, you can run it using the following command:

```sh
./atcmon.sh
```

## Dependencies Installation


> [!IMPORTANT]
> This script relies on two dependencies: `bc` and `jq`. They will be automatically installed during the first run if not already present on your system. You may be prompted for elevated permissions during this process.


### What are `bc` and `jq`?

-   **`bc`**: An arbitrary precision calculator language.
-   **`jq`**: A lightweight and flexible command-line JSON processor.

### Automatic Installation

When you run the script for the first time, it will check if `bc` and `jq` are installed. If they are not, the script will attempt to install them using your package manager.

### Supported Package Managers

The script supports the following package managers for automatic installation:

-   `apt-get` (for Debian-based distributions like Ubuntu)
-   `yum` (for Red Hat-based distributions like CentOS)
