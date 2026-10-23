# Monaco assets for ThetaRush

Monaco Editor and monaco-vim are served from `public/monaco` (static files).

## Update

`ash
npm install monaco-editor@0.52.2 monaco-vim@0.4.1 --prefix .tmp-monaco
# PowerShell:
Copy-Item -Recurse -Force .tmp-monaco\node_modules\monaco-editor\min\vs public\monaco\vs
Copy-Item -Force .tmp-monaco\node_modules\monaco-vim\dist\monaco-vim.js public\monaco\monaco-vim.js
`

Do not run contestant code in the browser outside the Monaco editor UI; judging stays on Judge0 CE.
