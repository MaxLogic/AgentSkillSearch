# Icon Candidate Review

## Goal

Create and compare 10 replacement app icon candidates for `Agent Skill Search`:

- 5 generated with `advanced-nano-banana-pro`
- 5 generated with `codex-openai-images`

All outputs are stored in this folder tree. The selected winner is:

- `winner-openai-01-tag-lens.ico`
- `winner-openai-01-tag-lens.png`

## Current Icon Audit

The current app icon still has the packaging problem we suspected:

- `assets/app-icon.ico[0]` is `256x256 srgb opaque=true`
- `assets/app-icon.ico[1]` is `128x128 srgba opaque=true`
- `assets/app-icon.ico[2]` is `64x64 srgba opaque=true`
- `assets/app-icon.ico[3]` is `48x48 srgba opaque=true`

That means the large layer is fully opaque, and the embedded icon stack is not preserving usable transparency the way we want.

## Comparison Method

We rated each candidate on:

- Transparency correctness
- Readability at `32x32`
- Readability at `16x16`
- Semantic fit for "Agent Skill Search"

Reference sheets:

- `contact-sheets/candidates-128.png`
- `contact-sheets/candidates-32.png`
- `contact-sheets/candidates-16.png`

## Ratings

Scale: `0-10`, higher is better.

| Rank | File | Model | Transparency | 32 px | 16 px | Fit | Overall | Notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | `openai/openai-01-tag-lens.ico` | OpenAI | 10 | 9 | 9 | 9 | 9.2 | Best balance of search cue + tag cue; stays readable at small sizes. |
| 2 | `openai/openai-02-folder-lens.ico` | OpenAI | 10 | 9 | 9 | 8 | 8.9 | Strong silhouette; slightly more file-search than skill-search. |
| 3 | `openai/openai-04-node-lens.ico` | OpenAI | 10 | 8 | 8 | 8 | 8.4 | Clean and semantic, but less immediate than the tag version. |
| 4 | `openai/openai-03-cards-lens.ico` | OpenAI | 10 | 7 | 7 | 8 | 7.9 | Good concept, but the card stack gets busy faster. |
| 5 | `openai/openai-05-bookmark-spark.ico` | OpenAI | 10 | 8 | 8 | 6 | 7.8 | Crisp shape, but the meaning drifts toward bookmark/favorite. |
| 6 | `nano-banana/nano-04-node-lens.ico` | Nano Banana | 2 | 8 | 7 | 8 | 5.9 | Best Nano Banana concept, but still opaque in this run. |
| 7 | `nano-banana/nano-01-tag-lens.ico` | Nano Banana | 2 | 7 | 5 | 9 | 5.8 | Good idea, but the light tile and low contrast hurt small sizes. |
| 8 | `nano-banana/nano-03-cards-lens.ico` | Nano Banana | 2 | 6 | 5 | 8 | 5.2 | Acceptable concept; still too light and not truly transparent. |
| 9 | `nano-banana/nano-02-folder-lens.ico` | Nano Banana | 2 | 6 | 4 | 7 | 4.8 | Reads as a dark block at small sizes. |
| 10 | `nano-banana/nano-05-bookmark-spark.ico` | Nano Banana | 2 | 5 | 4 | 5 | 4.0 | Too abstract for the app and still opaque. |

## Recommendation

Preferred replacement:

- `winner-openai-01-tag-lens.ico`

Why this one:

- real alpha transparency in the PNG and generated `.ico`
- strong silhouette at `16x16` and `32x32`
- combines search + tagging in one mark, which matches the app better than a plain folder
- less detailed and less noisy than the current icon

Fallback if we want a more file-centric meaning:

- `openai/openai-02-folder-lens.ico`
