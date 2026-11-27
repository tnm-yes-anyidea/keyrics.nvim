# keyrics.nvim 🎵⌨️



A  typing test built directly into Neovim, powered by live song lyrics from the [LRCLIB](https://lrclib.net/) API.

Instead of typing boring programming syntax or random quotes, practice your typing speed by following along to your favorite English songs. `keyrics.nvim` features a Typr-style in-place overwrite UI, a live floating HUD, and a rhythm-based typing mode that syncs with actual song timestamps.

## ✨ Features

* **In-Place Overwriting:** A seamless, scrolling-paragraph aesthetic. Your keystrokes colorize the lyrics in real-time, projecting the remaining text directly ahead of your cursor.

* **Live Floating HUD:** Tracks Words Per Minute (WPM) and Accuracy as you type.

* **Telescope Integration:** Fuzzy-find artist and song names using a lightweight, single-fetch Go backend that respects LRCLIB's rate limits.

* **Three Practice Modes:** Choose between casual typing, live endurance pacing, or rhythm-based LRC synced typing.

## 📸 Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/ba30bf21-342e-4584-9fe3-dd8cc3d6d70f" width="80%" alt="Screenshot 1">
  <br><br>
  <img src="https://github.com/user-attachments/assets/911cc003-5789-4c5b-86e4-a36c868dd5ae" width="80%" alt="Screenshot 2">
  <br><br>
  <img src="https://github.com/user-attachments/assets/f654b681-af2a-42ec-833e-adba2a9fd4d0" width="80%" alt="Screenshot 3">
  <br><br>
  <img src="https://github.com/user-attachments/assets/ae00d55d-25ee-4119-96f0-07b0497a23ae" width="80%" alt="Screenshot 4">
  <br><br>
  <img src="https://github.com/user-attachments/assets/26f6004a-cd49-4a1c-8381-a419982a2168" width="80%" alt="Screenshot 5">
  <br><br>
  <img src="https://github.com/user-attachments/assets/be96ae18-b39d-46ef-9ffb-4f83196ccdf7" width="80%" alt="Screenshot 6">
</p>

## ⚡️ Prerequisites

* **Neovim** >= 0.9.0

* **Go** (Golang) installed and available in your system `PATH`

* [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)



## 📦 Installation



Install using [Lazy.nvim](https://github.com/folke/lazy.nvim).



> **Note:** The `build` step is required. It automatically compiles the Go backend when the plugin is installed.



```lua
return {
    "tnm-yes-anyidea/keyrics.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    cmd = "Keyrics", -- Forces Neovim to recognize the command immediately
    config = function()
        require("keyrics")
        vim.keymap.set('n', '<leader>k', ':Keyrics<CR>', { noremap = true, silent = true, desc = "Start Keyrics Typing Test" })
    end
}

```



## 🚀 Usage



Launch the plugin using your configured keybind (e.g., `<leader>k`), or run the command directly:

```vim

:Keyrics

```



1. You will be prompted to search for an Artist or Song Name.

2. Telescope will open with the search results. You can preview the lyrics in the side panel before selecting a track.

3. Upon selection, choose one of the three typing modes.



### 🎮 The Modes



**1. Normal Typing (Cleaned)**

A relaxed typing environment. Irregular spacing and blank lines are stripped away. The UI waits for you to correct your mistakes and automatically advances the instant you complete the line.



**2. Endurance Mode (Live Pacing)**

The true Monkeytype experience. Your live WPM and Accuracy percentage float on the side of the window, updating with every single keystroke.



**3. Synced Typing (LRC Rhythm)**

Puts your speed to the test against the actual flow of the song. This mode parses the exact `[mm:ss.xx]` LRC timestamps and advances the lyrics out from under your fingers to the beat of the track. If you type too slowly, you lose the line.



## 🎵 A Personal Note



There are certainly better, more feature-rich general typing plugins out there (like [Typr](https://github.com/nvzone/typr) and [speedtyper.nvim](https://github.com/NStefan002/speedtyper.nvim)).



However, `keyrics.nvim` is a hobby project built specifically to offer a fun, niche alternative for audiophiles—giving you a way to practice your typing speed while flowing through the lyrics of your favorite songs rather than random words or code snippets.
