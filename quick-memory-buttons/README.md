# Quick Memory Buttons for Proxmox VM Wizard

Original Developer: [Link to Reddit Post](https://www.reddit.com/r/Proxmox/comments/181myjb/userscript_for_quick_memory_buttons_in_vm_wizard/)

![Screenshot](https://i.redd.it/gaiusw2bgz1c1.png)

This script adds quick memory buttons to your Proxmox Virtual Machine (VM) Wizard to simplify the process of configuring memory settings for your virtual machines.

## Installation

1. Make sure you have a user script manager extension installed in your browser. You can use extensions like Tampermonkey or Greasemonkey.

2. Download the [quick-memory-buttons.user.js](quick-memory-buttons.user.js) script file from this repository.

3. Open the script file using your user script manager extension, and it should prompt you to install the script.

4. After installation, the script will be active on your Proxmox Virtual Environment (VE) web interface.

## Usage

Once the script is installed, visit your Proxmox VE web interface. When you open the VM Wizard to create or edit a virtual machine, you should see additional quick memory buttons that allow you to easily set memory sizes for common configurations.

## Customization

If you need to customize the script for your specific Proxmox setup, make sure to update the `@match` metadata at the beginning of the script to match your Proxmox URL. This ensures that the script is applied correctly to your Proxmox VE instance.

```javascript
// @match       https://your-proxmox-url.tld/*
