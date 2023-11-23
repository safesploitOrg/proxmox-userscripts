// ==UserScript==
// @name         Proxmox Quick VM Memory Buttons
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  Add memory size buttons to the Create VM Wizard
// @author       _Landmine_ from Reddit
// @match        https://10.0.0.100:8006
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // Converts GB to MiB
    function gbToMiB(gb) {
        return gb * 1024;
    }

    // Creates a button element
    function createButton(size) {
        const button = document.createElement('button');
        button.textContent = `${size}GB`;
        button.style.marginRight = '5px';
        button.onclick = function() {
            const inputField = document.querySelector('input[name="memory"]');
            if (inputField) {
                inputField.focus();
                inputField.value = gbToMiB(size);
                inputField.dispatchEvent(new Event('input', { bubbles: true }));
                inputField.dispatchEvent(new Event('change', { bubbles: true }));
                inputField.blur();
            }
        };

        return button;
    }

    // Adds buttons to the panel
    function addButtons(panelBody) {
        const memorySizes = [1, 2, 4, 8, 16, 32, 64];
        const buttonContainer = document.createElement('div');
        buttonContainer.id = 'custom-button-container';
        buttonContainer.style.display = 'flex';
        buttonContainer.style.flexDirection = 'row';
        buttonContainer.style.alignItems = 'center';
        buttonContainer.style.justifyContent = 'flex-start';

        memorySizes.forEach(size => {
            buttonContainer.appendChild(createButton(size));
        });

        panelBody.appendChild(buttonContainer);
    }

    // Main function to find the memory input and place buttons next to it
    function placeButtons() {
        const labels = document.querySelectorAll('label.x-form-item-label');
        const memoryLabel = Array.from(labels).find(label => label.textContent.includes('Memory (MiB):'));

        if (memoryLabel) {
            const inputFieldContainer = memoryLabel.closest('.x-form-item');
            const panel = inputFieldContainer.closest('.x-panel');

            let panelBody = panel.nextElementSibling.querySelector('.x-panel-body');
            if (!panelBody) {
                panelBody = document.createElement('div');
                panelBody.classList.add('x-panel-body', 'x-panel-body-default');
                panel.nextElementSibling.appendChild(panelBody);
            }

            panel.style.height = 'auto';
            panel.nextElementSibling.style.height = 'auto';
            panelBody.style.height = 'auto';

            if (!panelBody.querySelector('#custom-button-container')) {
                addButtons(panelBody);
            }
        }
    }

    // Use a MutationObserver to listen for changes in the DOM
    const observer = new MutationObserver(mutations => {
        let shouldPlaceButtons = false;

        for (const mutation of mutations) {
            if (mutation.addedNodes.length || mutation.type === 'attributes') {
                shouldPlaceButtons = true;
            }
        }

        if (shouldPlaceButtons) {
            placeButtons();
        }
    });

    observer.observe(document.body, {
        childList: true,
        attributes: true,
        subtree: true,
        attributeFilter: ['style', 'class']
    });

    placeButtons();
})();
