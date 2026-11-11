// Plain-assert test for searchScore.js. The file is a QML `.pragma library`
// (no `export`), so evaluate its source in a vm context and read the
// top-level functions back off it.
import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const ctx = vm.createContext({})
const src = fs.readFileSync(new URL("./searchScore.js", import.meta.url), "utf8")
vm.runInContext(src.replace(/^\.pragma.*$/m, ""), ctx)
const { score, rank, calc } = ctx

const app = (name, extra = {}) => ({ id: name, name, generic: "", keywords: [], ...extra })
const names = (r) => r.map((x) => x.name)
const q = (query, items, counts = {}, limit) => names(rank(items, query, counts, limit))

// tier order: exact > prefix > word-start > substring > generic/keywords > fuzzy > none
const tiers = [
  score("code", app("Code")),
  score("code", app("Code Editor")),
  score("code", app("Visual Studio Code")),
  score("code", app("Barcode Scanner")),
  score("code", app("Editor", { generic: "Code Editor" })),
  score("cde", app("Code Editor!x")),
]
for (let i = 0; i < tiers.length - 1; i++) assert.ok(tiers[i] > tiers[i + 1], `tier ${i} > ${i + 1}: ${tiers}`)
assert.ok(tiers[tiers.length - 1] > 0)
assert.equal(score("zzz", app("Firefox")), 0)

// initials and fuzzy
assert.ok(score("vsc", app("Visual Studio Code")) >= 700, "initials count as word-start")
assert.ok(score("ff", app("Firefox")) > 0)
assert.ok(score("thnr", app("Thunar")) > 0)

// prefix beats mid-word substring, regardless of alphabet
assert.deepEqual(q("fire", [app("Backfire"), app("Firefox")]), ["Firefox", "Backfire"])

// keyword-only match still found; non-matches excluded
const kw = app("Zathura", { keywords: ["pdf", "viewer"] })
assert.deepEqual(q("pdf", [kw, app("Firefox")]), ["Zathura"])

// ties: launch count, then alphabetical
assert.deepEqual(q("e", [app("Beta"), app("Alpha e"), app("Gamma e")], { "Gamma e": 5 }).slice(0, 1), ["Gamma e"])
assert.deepEqual(q("ap", [app("Apple", { id: "b" }), app("Apricot", { id: "a" })], { b: 3 }), ["Apple", "Apricot"])
assert.deepEqual(q("ap", [app("Apple"), app("Apricot")]), ["Apple", "Apricot"])

// empty query: launch count desc, then name; limit applies
assert.deepEqual(q("", [app("B"), app("A"), app("C")], { C: 2 }), ["C", "A", "B"])
assert.deepEqual(q("", [app("B"), app("A"), app("C")], {}, 2), ["A", "B"])

// calculator: whitelist only, ^ is power
assert.equal(calc("2+3*4"), 14)
assert.equal(calc("2^10"), 1024)
assert.equal(calc("(1+2)*3"), 9)
assert.equal(calc("1,5+1"), 2.5)
assert.equal(calc("10 % 4"), 2)
assert.equal(calc("-3+5"), 2)
assert.equal(calc("2^3^2"), 512, "power is right-associative")
for (const bad of ["", "42", "alert(1)", "2+", "1/0", "process.exit()", "2**3", "(1", "1 2", "a+1", "1+1;1"])
  assert.equal(calc(bad), null, `reject ${bad}`)

console.log("ok")
