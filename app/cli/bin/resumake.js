#!/usr/bin/env node

'use strict'

const path = require('path')
const fs = require('fs')

// Register babel so we can require the server's ES6/Flow source directly
require('babel-register')({
  presets: ['env', 'flow'],
  only: /app[/\\]server[/\\]src/
})

const { generatePDF } = require('../../server/src/generator/index')
const { sanitize } = require('../../server/src/middleware/sanitizer')

function parseArgs(argv) {
  const args = argv.slice(2)

  if (args.length === 0) {
    console.error('Usage: resumake <path-to-json> [-style1..-style9]')
    console.error('Example: resumake resume.json -style2')
    process.exit(1)
  }

  const jsonPath = args.find(a => !a.startsWith('-style'))
  const styleFlag = args.find(a => /^-style[1-9]$/.test(a))

  if (!jsonPath) {
    console.error('Error: No JSON file path provided.')
    process.exit(1)
  }

  const selectedTemplate = styleFlag ? parseInt(styleFlag.replace('-style', ''), 10) : 1

  return { jsonPath, selectedTemplate }
}

function main() {
  const { jsonPath, selectedTemplate } = parseArgs(process.argv)

  const resolvedPath = path.resolve(process.cwd(), jsonPath)

  if (!fs.existsSync(resolvedPath)) {
    console.error(`Error: File not found: ${resolvedPath}`)
    process.exit(1)
  }

  let rawData
  try {
    rawData = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'))
  } catch (e) {
    console.error(`Error: Could not parse JSON — ${e.message}`)
    process.exit(1)
  }

  const formData = sanitize(Object.assign({}, rawData, { selectedTemplate }))

  const outputPath = path.join(process.cwd(), 'resume.pdf')
  const output = fs.createWriteStream(outputPath)

  console.log(`Generating resume with style ${selectedTemplate}...`)

  const pdf = generatePDF(formData)

  pdf.pipe(output)

  pdf.on('error', err => {
    console.error(`Error generating PDF: ${err.message}`)
    process.exit(1)
  })

  output.on('finish', () => {
    console.log(`Done! Saved to: ${outputPath}`)
  })
}

main()
