unit PreviewEmptyStateHtml;

interface

function GetPreviewEmptyStateHtml: string;

implementation

const
  // Rated candidate directions:
  // 1. Workshop noteboard: 9.3/10 (selected)
  // 2. Paper ticket rail: 8.9/10
  // 3. Terminal postcard: 8.4/10
  // 4. Cabinet drawer card: 8.1/10
  // 5. Signboard marker sketch: 7.6/10
  cPreviewEmptyStateHtml =
    '<!DOCTYPE html>' +
    '<html lang="en">' +
    '<head>' +
    '  <meta charset="utf-8">' +
    '  <meta name="viewport" content="width=device-width, initial-scale=1">' +
    '  <title>Pick a skill</title>' +
    '  <link rel="preconnect" href="https://fonts.googleapis.com">' +
    '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' +
    '  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap" rel="stylesheet">' +
    '  <style>' +
    '    :root {' +
    '      color-scheme: dark;' +
    '      --bg: #15110e;' +
    '      --panel: #201915;' +
    '      --panel-2: #2a211c;' +
    '      --edge: #4a382d;' +
    '      --accent: #d59a4a;' +
    '      --accent-soft: #8f6737;' +
    '      --text: #f5ead8;' +
    '      --muted: #c5b39c;' +
    '    }' +
    '    * { box-sizing: border-box; }' +
    '    html, body { height: 100%; margin: 0; }' +
    '    body {' +
    '      min-height: 100%;' +
    '      font-family: "IBM Plex Sans", sans-serif;' +
    '      background:' +
    '        radial-gradient(circle at top right, rgba(213,154,74,0.08), transparent 34%),' +
    '        repeating-linear-gradient(0deg, rgba(255,255,255,0.03), rgba(255,255,255,0.03) 1px, transparent 1px, transparent 28px),' +
    '        linear-gradient(180deg, #181310 0%, var(--bg) 100%);' +
    '      color: var(--text);' +
    '      display: flex;' +
    '      align-items: center;' +
    '      justify-content: center;' +
    '      padding: 28px;' +
    '    }' +
    '    .board {' +
    '      width: min(760px, 100%);' +
    '      display: grid;' +
    '      grid-template-columns: 220px minmax(0, 1fr);' +
    '      gap: 24px;' +
    '      padding: 24px;' +
    '      border: 1px solid var(--edge);' +
    '      background: linear-gradient(180deg, rgba(42,33,28,0.96), rgba(32,25,21,0.96));' +
    '      box-shadow: 0 10px 28px rgba(0,0,0,0.28);' +
    '      overflow: hidden;' +
    '      position: relative;' +
    '    }' +
    '    .board::before {' +
    '      content: "";' +
    '      position: absolute;' +
    '      inset: 0;' +
    '      border-top: 4px solid var(--accent-soft);' +
    '      opacity: 0.85;' +
    '      pointer-events: none;' +
    '    }' +
    '    .stage {' +
    '      min-height: 250px;' +
    '      border: 1px solid rgba(213,154,74,0.3);' +
    '      background: linear-gradient(180deg, rgba(27,22,18,0.85), rgba(19,16,13,0.9));' +
    '      display: flex;' +
    '      flex-direction: column;' +
    '      justify-content: space-between;' +
    '      padding: 14px;' +
    '    }' +
    '    .lottie-host {' +
    '      height: 164px;' +
    '      width: 100%;' +
    '    }' +
    '    .mini-row {' +
    '      display: flex;' +
    '      align-items: center;' +
    '      gap: 10px;' +
    '      border-top: 1px solid rgba(213,154,74,0.18);' +
    '      padding-top: 10px;' +
    '      color: var(--muted);' +
    '      font-size: 13px;' +
    '    }' +
    '    .mini-lottie {' +
    '      width: 34px;' +
    '      height: 34px;' +
    '      flex: 0 0 auto;' +
    '    }' +
    '    .copy {' +
    '      display: flex;' +
    '      flex-direction: column;' +
    '      justify-content: center;' +
    '      gap: 16px;' +
    '      min-width: 0;' +
    '    }' +
    '    .title {' +
    '      margin: 0;' +
    '      font-size: clamp(31px, 5vw, 44px);' +
    '      line-height: 1.02;' +
    '      letter-spacing: -0.03em;' +
    '      font-weight: 600;' +
    '      max-width: 9ch;' +
    '    }' +
    '    .title strong {' +
    '      color: var(--accent);' +
    '      font-weight: 600;' +
    '    }' +
    '    .body {' +
    '      margin: 0;' +
    '      max-width: 34ch;' +
    '      font-size: 17px;' +
    '      line-height: 1.58;' +
    '      color: var(--muted);' +
    '    }' +
    '    .details {' +
    '      display: grid;' +
    '      gap: 8px;' +
    '      font-family: "IBM Plex Mono", monospace;' +
    '      font-size: 13px;' +
    '      color: #e6d3bb;' +
    '    }' +
    '    .details div {' +
    '      padding: 9px 0;' +
    '      border-top: 1px solid rgba(255,255,255,0.08);' +
    '    }' +
    '    .details em {' +
    '      font-style: normal;' +
    '      color: var(--accent);' +
    '    }' +
    '    @media (max-width: 640px) {' +
    '      body { padding: 16px; }' +
    '      .board { grid-template-columns: 1fr; gap: 18px; padding: 18px; }' +
    '      .stage { min-height: 0; }' +
    '      .title { max-width: none; }' +
    '      .body { max-width: none; }' +
    '    }' +
    '  </style>' +
    '</head>' +
    '<body>' +
    '  <main class="board" aria-label="Empty skill preview">' +
    '    <section class="stage" aria-hidden="true">' +
    '      <div id="heroLottie" class="lottie-host"></div>' +
    '      <div class="mini-row">' +
    '        <div id="miniLottie" class="mini-lottie"></div>' +
    '        <div>Waiting for a good pick.</div>' +
    '      </div>' +
    '    </section>' +
    '    <section class="copy">' +
    '      <h1 class="title">Pick a skill on the left and <strong>I''ll crack it open.</strong></h1>' +
    '      <p class="body">No rush. I''m parked here until you choose one. Once you do, I''ll show the summary, tags, scripts, duplicates, and the good bits without making you dig around for them.</p>' +
    '      <div class="details">' +
    '        <div><em>Ctrl+R</em> jumps to the results list.</div>' +
    '        <div><em>Enter</em> opens the selected skill.</div>' +
    '        <div><em>Ctrl+Enter</em> opens the skill folder.</div>' +
    '      </div>' +
    '    </section>' +
    '  </main>' +
    '  <script src="https://cdnjs.cloudflare.com/ajax/libs/bodymovin/5.12.2/lottie.min.js"></script>' +
    '  <script>' +
    '    (function () {' +
    '      function mount(id, path) {' +
    '        if (!window.lottie) return;' +
    '        var host = document.getElementById(id);' +
    '        if (!host) return;' +
    '        window.lottie.loadAnimation({' +
    '          container: host,' +
    '          renderer: "svg",' +
    '          loop: true,' +
    '          autoplay: true,' +
    '          path: path' +
    '        });' +
    '      }' +
    '      mount("heroLottie", "https://assets5.lottiefiles.com/packages/lf20_uqaiiqu0.json");' +
    '      mount("miniLottie", "https://assets1.lottiefiles.com/packages/lf20_ISbOsd.json");' +
    '    }());' +
    '  </script>' +
    '</body>' +
    '</html>';

function GetPreviewEmptyStateHtml: string;
begin
  Result := cPreviewEmptyStateHtml;
end;

end.
