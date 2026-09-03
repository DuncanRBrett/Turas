# qual_inline_strings fixture

`inline_strings_openpyxl.xlsx` was written by openpyxl 3.1.5 on 3 Sep 2026 and must stay
openpyxl-written: the point of the fixture is that openpyxl stores every string as an inline
string (`<c t="inlineStr"><is><t>`), which openxlsx 4.2.x reads without unescaping XML
entities or handling the `xml:space` attribute. Do not open and re-save it in Excel; Excel
rewrites it with shared strings and the fixture stops exercising the bug.

Sheet `Probe`: six comments covering ampersand, leading/trailing space, newline, plain text
and the other entities. Sheet `Padded`: a coded sheet whose sentiment header is
`" Overall Sentiment "` and whose theme header carries an ampersand and a trailing space.

Regenerate (if ever needed) with the snippet in
`modules/tabs/tests/testthat/test_qual_inline_strings.R`.
