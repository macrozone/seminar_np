defaultArgs = "-V documentclass=article -H zhawsettings.tex -o out.pdf --table-of-contents --listing --filter pandoc-citeproc --number-sections -s --template=template.latex"
spawn = require("child_process").spawn
path = require('path')
fs = require "fs"
ect = require("ect")()


precompileAndRead = (file) ->
	extension = path.extname file
	switch extension
		when ".ect" then ect.render file
		else fs.readFileSync file

pandoc = spawn "pandoc", defaultArgs.split(" ").concat ["-o", "out.pdf"]

files = [
	"10.md.ect"
]
pandoc.stderr.on "data", (data) ->
	console.error data.toString "utf-8"
for file in files
	pandoc.stdin.write precompileAndRead file

pandoc.stdin.end()
