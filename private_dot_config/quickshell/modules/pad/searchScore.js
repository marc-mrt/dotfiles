.pragma library

// Pad search ranking and calculator, kept as plain JS so it is testable
// with node (searchScore.test.mjs) without a running shell. No QML types in
// here, which is also what lets `.pragma library` share one instance.

// Tiers are spaced far apart so nothing but the tier decides order; launch
// count and name only break ties (see rank()).
const EXACT = 1000, PREFIX = 800, WORD = 700, SUBSTR = 600, META = 400, FUZZY = 200

function isSubsequence(q, s) {
    let i = 0
    for (let j = 0; j < s.length && i < q.length; j++)
        if (s[j] === q[i]) i++
    return i === q.length
}

// item: { name, generic?, keywords? (array or string) } -> 0 means no match.
function score(query, item) {
    const q = query.trim().toLowerCase()
    const name = (item.name || "").toLowerCase()
    if (!q) return 1
    if (name === q) return EXACT
    if (name.startsWith(q)) return PREFIX
    // Word starts: "code" in "visual studio code", or the initials "vsc".
    const words = name.split(/[^a-z0-9]+/).filter(w => w)
    if (words.some(w => w.startsWith(q)) || words.map(w => w[0]).join("").startsWith(q))
        return WORD
    if (name.includes(q)) return SUBSTR
    const kw = Array.isArray(item.keywords) ? item.keywords.join(" ") : (item.keywords || "")
    if (((item.generic || "") + " " + kw).toLowerCase().includes(q)) return META
    if (isSubsequence(q, name)) return FUZZY
    return 0
}

// Matches only, best first: score, then launch count (counts[id]), then name.
// Empty query keeps everything, so it degrades to "most launched first".
function rank(items, query, counts, limit) {
    const out = items
        .map(it => ({ it: it, s: score(query, it), n: (counts && counts[it.id]) || 0 }))
        .filter(x => x.s > 0)
        .sort((a, b) => b.s - a.s || b.n - a.n || a.it.name.localeCompare(b.it.name))
        .map(x => x.it)
    return limit ? out.slice(0, limit) : out
}

// Pure arithmetic only: the input is whatever the user typed into the search
// box, so it is whitelisted and then run through a small parser. It is never
// handed to eval(). Returns a finite number, or null when the text isn't an
// expression (a bare number isn't one: "42" should search, not calculate).
function calc(expr) {
    if (!/^[0-9\s+\-*\/%^().,]+$/.test(expr)) return null
    // Spaces split tokens, so "1 2" stays an error rather than becoming 12.
    const toks = expr.replace(/,/g, ".").match(/\d+\.?\d*|\.\d+|[-+*\/%^()]/g)
    if (!toks || toks.join("").length !== expr.replace(/\s/g, "").replace(/,/g, ".").length)
        return null
    let pos = 0, binary = false
    const fail = () => { throw new Error("parse") }
    const peek = () => toks[pos]
    function atom() {
        const t = toks[pos++]
        if (t === "(") {
            const v = sum()
            if (toks[pos++] !== ")") fail()
            return v
        }
        if (t === undefined || !/^[\d.]/.test(t)) fail()
        return parseFloat(t)
    }
    // ^ is right-associative and binds tighter than unary minus on its left
    // (-2^2 = -4) but accepts one on its right (2^-1).
    function power() {
        const b = atom()
        if (peek() === "^") { pos++; binary = true; return Math.pow(b, unary()) }
        return b
    }
    function unary() {
        if (peek() === "-") { pos++; return -unary() }
        if (peek() === "+") { pos++; return unary() }
        return power()
    }
    function product() {
        let v = unary()
        while (peek() === "*" || peek() === "/" || peek() === "%") {
            const op = toks[pos++]; binary = true
            const r = unary()
            v = op === "*" ? v * r : op === "/" ? v / r : v % r
        }
        return v
    }
    function sum() {
        let v = product()
        while (peek() === "+" || peek() === "-") {
            const op = toks[pos++]; binary = true
            const r = product()
            v = op === "+" ? v + r : v - r
        }
        return v
    }
    try {
        const v = sum()
        return pos === toks.length && binary && isFinite(v) ? v : null
    } catch (e) {
        return null
    }
}
