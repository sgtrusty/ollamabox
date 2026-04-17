# 📦 Ollama Sandboxed Manager

A rootless, air-gapped management script for **Ollama**. This tool uses `bubblewrap` (bwrap) to containerize the Ollama engine, ensuring it has zero access to your host filesystem (outside of its specific model/cache directories) and stays isolated from your network unless explicitly permitted.

## 🛡️ Key Security Features

- **Rootless:** Runs entirely in user-space. No sudo required.
- **Filesystem Isolation:** The Ollama binary only sees a virtualized environment. It cannot read your `$HOME` or sensitive system files.
- **Socket Bridging:** Uses `socat` to bridge internal container traffic to a Unix socket, preventing port conflicts on the host.
- **GPU Passthrough:** Specifically configured for NVIDIA hardware acceleration within the sandbox.

---

## 🚀 Getting Started

1. **Dependencies:** Ensure you have the following installed on your host:
   - `bwrap` (bubblewrap)
   - `socat`
   - `curl`
   - `zstd`
   - `fzf` (for model selection)
2. **Permissions:** Make the script executable:
   `chmod +x ollama-manager.sh`
3. **Run:** Execute the manager:
   `./ollama-manager.sh`

---

## 🛠️ Menu Options

| Option | Name               | Description                                                                           |
| :----- | :----------------- | :------------------------------------------------------------------------------------ |
| **1**  | **Start Server**   | Initializes the `bwrap` container and starts the Ollama API server in the background. |
| **2**  | **Stop Server**    | Kills all background processes, bridges, and cleans up temporary sockets.             |
| **3**  | **Download Model** | Uses a `models.csv` index or manual input to pull new LLMs into the sandbox.          |
| **4**  | **Run Model**      | Launches an interactive CLI chat session with a locally stored model.                 |
| **5**  | **List Models**    | Directly queries the API via the Unix socket to show available local models.          |
| **7**  | **Expose to LAN**  | Opens port **11435** to your local network for external tool integration.             |

---

## 🤖 Integration (Aider / OpenCode)

To use your sandboxed models with external consumer apps, follow these steps:

1. **Expose the Port:** Select **Option 7** in the menu. This bridges your internal Unix socket to `0.0.0.0:11435`.
2. **Configure the Client:**
   - **Aider:** `export OLLAMA_HOST=http://<YOUR_IP>:11435`
   - **OpenCode/VS Code:** Set the server URL to `http://<YOUR_IP>:11435`.

---

## 📂 Directory Structure

- `.ollama/installer/`: Contains the Ollama binary and library files.
- `.ollama/models/`: Persistent storage for your LLM weights.
- `.ollama/mntcache/`: Temporary cache used during model pulls.
- `/tmp/ollama_$(whoami)_run/`: Volatile directory for the Unix socket (cleared on exit).

---

## ⚠️ Troubleshooting

**"Broken Pipe" or "Connection Refused":**
This usually happens if the server hasn't fully initialized or a previous session didn't clean up properly. Select **Option 2 (Stop)** and then **Option 1 (Start)** to reset the environment.

**GPU Not Detected:**
The script currently looks for `/dev/nvidia0`. If you are using an AMD GPU or a multi-GPU setup, you will need to adjust the `gpu_flags` inside the `run_sandbox` function to point to your specific `/dev/dri/` or `/dev/kfd` nodes.

**Bubblewrap spawns uncleaned**:
In case that `bwrap` processes are not properly cleaned on exit, run something like `killall -9 bwrap` to clear up their allocated resources.
