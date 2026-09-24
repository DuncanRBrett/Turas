# The report narrative in Word: user manual and style guide

Written 24 September 2026. The rules below come from the narrative reader
(`modules/tabs/lib/crosstabs/narrative_reader.R`) and the Present renderer
(`assets/js/24b_narrative.js`, `30_story.js`). The screen sizes were measured
on the CCPB 2026 narrative in a 1280 x 720 window. That window is a Teams
share, the tightest screen Turas has to fit.

The narrative document holds the words a findings deck opens with: objectives
and method, the sample, the executive summary, and commentary such as NPS
drivers with quotes. Results come from pins: a question, a trend, a heatmap.
The document writes the argument, and the pins show the evidence.

---

## Part 1. User manual

### 1. Set it up

1. Write the document in Word and save it as `.docx`. The project folder,
   next to the config, is the natural place.
2. On the config's **Settings** sheet, put the file name in `narrative_file`.
   A relative path is read from the config file's own folder, so a file
   beside the config needs only its name.
3. Regenerate through `launch_turas()`.

With `narrative_file` set, the document replaces the Comments sheet's
`_BACKGROUND` and `_EXECUTIVE_SUMMARY` cells entirely. Leave the setting blank
to go back to those cells. If the file is not where the setting says, the run
refuses with `IO_NARRATIVE_FILE_NOT_FOUND` and prints where it looked.

### 2. What the console tells you

A clean read prints one or two lines:

```
[INFO] Narrative file CCPB_W2026_Narrative.docx: 13 screens, 51 blocks, 0 pictures
[INFO] Narrative file: 9 Turas links kept, to Q78, Q79, Q36, Q02, Q22, Q03, Q64, Q06, Q74.
```

Anything the reader skipped is named with a count and what to do about it,
for example `[WARNING] Narrative file: 2 hyperlink(s). The words are kept and
the link is dropped.` A link to a question code the report does not carry
gets its own warning naming the words and the code. Read these lines after
every regeneration. They are the only place a problem in the document shows.

### 3. How the document becomes screens

- Each **Heading 1** starts a screen, and its text is the screen's title. A
  house heading style built on Heading 1 counts too.
- Everything before the first Heading 1 is not read.
- A document with no headings at all becomes one screen called "Executive
  summary".
- Each screen's identity is its title. Pins follow the title, so renaming a
  heading in Word leaves its old pin saying the screen is no longer in the
  report. Re-pin it after a rename.
- The **cover** of a saved copy opens with the first screen whose title starts
  "Executive summary", or the first screen when none does. Keep that title if
  you want the summary on the cover.

Inside a screen Turas keeps:

- **Heading 2** as a sub-heading and **Heading 3** as a smaller one. Heading 4
  and below read as ordinary paragraphs.
- Paragraphs, with bold and italic. The **first paragraph is the lead** and
  shows larger on the slide.
- Bulleted and numbered lists, with their nesting and Word's own numbers.
- The **Quote** style, as a highlighted band.
- A **font colour** (anything but black or grey) as the brand colour, and the
  **highlighter** as a soft accent tint. Word's own colours never reach the
  page.
- Pictures (PNG, JPEG or GIF, up to 1.5 MB each).
- Simple tables: words only, no merged cells. The first row is the header.

These are skipped, and the console says so: text boxes, shapes, SmartArt,
native Word charts, footnotes, comments, headers and footers, embedded
objects, pictures inside tables, merged or nested tables, and content
controls. Tracked changes are read as if accepted, so accept or reject them
first.

### 4. Link words to a question

Select the words, press **Ctrl+K** (Cmd+K on a Mac) and type `turas:` and the
question code as the address, for example `turas:Q78`. In the report the
words become a link in the brand colour. A click opens that question in the
crosstabs with the reader's own banner and filters, and a bar offers Back to
where they were. In Present, Back returns to the same slide.

- Use the code exactly as the report carries it (`Q78`, not `q78`).
- Links work in paragraphs and bullets. In a heading or a table the words stay
  and the link goes.
- The PowerPoint export shows linked words as plain text.

### 5. Pictures

Size the picture in Word:

- A picture at **80% of the text width or more** is wide. It spans the slide
  where it sits in the text.
- A smaller picture sits in a column beside the words, taking about two
  fifths of the slide.

A dense exhibit, such as a table image or a ratings map with forty rows, is
unreadable in that column. Put it in the config's **AddedSlides** sheet
instead, and pin it like any other slide. CCPB's "Ratings heatmap" is an
example. In Present an added slide shows its picture at the full width of the
slide, under the slide's title and text. Measured on CCPB's map (2124 x 1294):
it fits a 1920 x 1080 screen, but on a 1280 x 720 share it is 978 logical
pixels tall and scrolls a little. Crop the picture to what the room needs,
and leave its own title out of the image, since the slide adds one.

### 6. Where the screens appear

- **Report tab:** one card per screen, each with a 📌 pin.
- **Story:** a new story starts with every screen pinned, in document order.
  After that they are ordinary pins, so a screen added to Word later is
  pinned by hand from the Report tab. Place the pins among the question pins
  in the order you will present them.
- **Present:** each screen is a slide on the 16:9 stage. Long lists flow into
  two columns, and quotes become bands.
- **PowerPoint export:** a text slide per screen, with "continued" slides when
  the words need more room.
- **Saved copy cover:** the "Executive summary" screen, as above.

### 7. Change it later

Edit the Word file, save it, close it, and regenerate. Pins are references to
the screen, not copies, so every pin shows the new wording. Only a renamed or
deleted heading needs attention (see section 3).

### 8. When something looks wrong

| What you see | Why | What to do |
|---|---|---|
| No screens at all, or the old Comments text | `narrative_file` blank, or not the file you edited | Check the setting and the path in the console line |
| Run refuses with `IO_NARRATIVE_FILE_NOT_FOUND` | Wrong name or folder | The message prints the path it tried |
| Some text missing | It sat in a text box, a shape, a footnote or above the first Heading 1 | Read the console WARNING lines, move the words into body text |
| A heading shows as body text | It is Heading 4 or lower, or a style not built on a heading | Apply Heading 1, 2 or 3 |
| A pin says the screen is no longer in the report | The heading was renamed or deleted | Pin the screen again from the Report tab |
| Linked words show as plain text | The code is not a question in the report, or the link is in a heading or table | Read the WARNING line, fix the code with Ctrl+K |
| A slide scrolls in Present | Too much on one screen | Split it (see the style guide) |

---

## Part 2. Style guide

### 1. One screen is one slide

Write each Heading 1 section for one 16:9 slide that a room reads in under a
minute. Everything on a screen should fit a Teams share without scrolling.
Measured on CCPB 2026 at 1280 x 720:

| Screen | Words | Content | Fit |
|---|---|---|---|
| Executive summary | 250 | lead, 11 bullets (two columns) | fits |
| NPS drivers: passives | 186 | 2 paragraphs, 5 quotes | just fits |
| Objectives and methodology | 150 | lead, 3 sub-headings, 10 bullets | fits |
| NPS drivers: promoters, before the split | 225 | 2 paragraphs, 6 quotes | scrolled |
| Centre analysis, before the split | 261 | lead, 4 sub-headings, 19 bullets | scrolled |

So, as a rule of thumb:

- up to about **250 words of bullets**, because a list of more than six items
  flows into two columns;
- up to about **five quotes** with a short introduction;
- up to **two sub-headed groups** of five or so bullets.

Past that, split the screen. Carry on under the same title with **(cont.)**:
"Centre analysis (cont.)", "Executive summary (cont.)". A continuation starts
with the words themselves, no repeated introduction.

A slide that is too full is not lost. It shrinks a little, then scrolls. But
in front of a room a scrolling slide looks unprepared, so split instead.

### 2. Titles

- Short and plain, in sentence case: "Objectives and methodology", "NPS
  drivers: detractors".
- Name the topic, not the finding. The finding goes in the lead paragraph.
- The summary screen's title starts with "Executive summary", so the cover
  finds it.
- Do not number titles. The story's order is set by the pins.

### 3. Open with the lead

The first paragraph shows larger than the rest. Make it the one sentence the
room should remember: "There were only 17 Detractors making up 2% of the
sample." Then bullets or quotes for the detail.

### 4. Bullets

- One idea per bullet, in one or two lines.
- Nest a bullet only when it belongs to the one above: "Improvements this
  year" and then its five items.
- More than six bullets on a screen flow into two columns in Present. That is
  deliberate, and it is what lets a 250-word summary fit. Write them so they
  read in either order.

### 5. Quotes

- Apply Word's **Quote** style, one quote per paragraph.
- Keep the respondent's words, including their grammar. Wrap them in curly
  quotation marks.
- Group quotes under a Heading 2 when they make different points, for example
  "Perceptions of favouritism" and "A lack of contact".
- Never use the same quote twice.

### 6. Numbers

- Every figure in the narrative must match the report, which the room can
  open. Copy the figure from the table, never from memory or an old deck.
- Link the words around a key figure to its question with `turas:`. The
  presenter can then click through to the table.
- Say the base where it matters ("n=30", "off a small sample"), as the deck
  would.

### 7. Emphasis and typography

- Use bold sparingly, for a word or two per screen.
- A font colour marks "stress this" and shows in the brand colour. Use it for
  one phrase a screen at most.
- Use no ALL CAPS sentences. They read as shouting, and Turas shows them as
  typed.
- Use no em dashes. Use a full stop, a comma or a colon.
- Use tables only for a small grid of words or figures, like the sample. A
  result table belongs in a pin, where it stays live.

### 8. What belongs in Word and what does not

| In the Word document | As a pin |
|---|---|
| Objectives, method, sample | A question's table or chart |
| Executive summary | A distribution and trend exhibit |
| Commentary with quotes (NPS drivers) | Priority comments on a question |
| Short notes on groups too small for the data | A heatmap or composite |
| | A dense picture, via AddedSlides (see Part 1, section 5) |

### 9. A running order that works

1. Objectives and methodology
2. Sample
3. Executive summary, then (cont.)
4. The headline pins: overall rating, NPS
5. The driver screens with their quotes
6. Section by section: a short narrative screen if needed, then its pins
7. Notes on small groups (for CCPB, the Bengali, Ethiopian and Somali
   perspectives)

---

## Worked example

`CCPB_W2026_Narrative.docx` (CCPB CSAT W2026) was built from the text of the
2026 deck. It follows this guide: 13 screens, 9 links, and the dense ratings
map left to the AddedSlides "Ratings heatmap". Every one of its 13 screens was
measured to fit 1280 x 720 without scrolling (the heatmap slide, which is not
part of the document, does scroll there; see Part 1, section 5).
