unit UpdateAvailableDialogHtml;

interface

function GetUpdateAvailableVisualHtml: string;

implementation

const
  // Rated visual directions:
  // 1. Dispatch postcard: 9.2/10 (selected)
  // 2. Launch ticket: 8.8/10
  // 3. Toolbox note: 8.4/10
  // 4. Neon beacon card: 8.1/10
  // 5. Bulletin stripe: 7.7/10
  cUpdateAvailableVisualHtml =
    '<!DOCTYPE html>' +
    '<html lang="en">' +
    '<head>' +
    '  <meta charset="utf-8">' +
    '  <meta name="viewport" content="width=device-width, initial-scale=1">' +
    '  <title>Update available</title>' +
    '  <link rel="preconnect" href="https://fonts.googleapis.com">' +
    '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' +
    '  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@500&family=Fraunces:opsz,wght@9..144,600&display=swap" rel="stylesheet">' +
    '  <style>' +
    '    :root {' +
    '      color-scheme: light;' +
    '      --paper: #fff6ea;' +
    '      --ink: #2f2014;' +
    '      --muted: #6d5747;' +
    '      --accent: #d26a2e;' +
    '      --line: rgba(88, 55, 31, 0.16);' +
    '    }' +
    '    * { box-sizing: border-box; }' +
    '    html, body { height: 100%; margin: 0; }' +
    '    body {' +
    '      min-height: 100%;' +
    '      display: flex;' +
    '      align-items: stretch;' +
    '      justify-content: stretch;' +
    '      background:' +
    '        radial-gradient(circle at top right, rgba(210,106,46,0.12), transparent 34%),' +
    '        linear-gradient(180deg, #fffaf3 0%, var(--paper) 100%);' +
    '      color: var(--ink);' +
    '      overflow: hidden;' +
    '    }' +
    '    .wrap {' +
    '      flex: 1;' +
    '      padding: 22px;' +
    '      display: grid;' +
    '      grid-template-rows: auto 1fr auto;' +
    '      gap: 14px;' +
    '    }' +
    '    .eyebrow {' +
    '      display: inline-flex;' +
    '      align-items: center;' +
    '      gap: 8px;' +
    '      font: 500 11px/1 "IBM Plex Mono", monospace;' +
    '      text-transform: uppercase;' +
    '      letter-spacing: 0.18em;' +
    '      color: var(--accent);' +
    '    }' +
    '    .eyebrow::before {' +
    '      content: "";' +
    '      width: 18px;' +
    '      height: 1px;' +
    '      background: currentColor;' +
    '      opacity: 0.8;' +
    '    }' +
    '    h1 {' +
    '      margin: 0;' +
    '      max-width: 9ch;' +
    '      font-family: "Fraunces", serif;' +
    '      font-size: clamp(28px, 5vw, 42px);' +
    '      line-height: 0.95;' +
    '      letter-spacing: -0.04em;' +
    '    }' +
    '    p {' +
    '      margin: 0;' +
    '      max-width: 24ch;' +
    '      color: var(--muted);' +
    '      font: 500 15px/1.5 "IBM Plex Mono", monospace;' +
    '    }' +
    '    .card {' +
    '      border: 1px solid var(--line);' +
    '      border-radius: 22px;' +
    '      background: rgba(255, 255, 255, 0.55);' +
    '      box-shadow: 0 10px 28px rgba(73, 44, 24, 0.08);' +
    '      padding: 12px;' +
    '      display: flex;' +
    '      align-items: center;' +
    '      justify-content: center;' +
    '      min-height: 188px;' +
    '    }' +
    '    #heroLottie {' +
    '      width: min(240px, 100%);' +
    '      height: 180px;' +
    '    }' +
    '    .footer {' +
    '      display: flex;' +
    '      align-items: center;' +
    '      gap: 10px;' +
    '      font: 500 12px/1.4 "IBM Plex Mono", monospace;' +
    '      color: var(--muted);' +
    '    }' +
    '    .dot {' +
    '      width: 8px;' +
    '      height: 8px;' +
    '      border-radius: 999px;' +
    '      background: var(--accent);' +
    '      box-shadow: 0 0 0 5px rgba(210,106,46,0.12);' +
    '    }' +
    '  </style>' +
    '</head>' +
    '<body>' +
    '  <main class="wrap" aria-hidden="true">' +
    '    <div class="eyebrow">Fresh build spotted</div>' +
    '    <div>' +
    '      <h1>Something newer is waving at us.</h1>' +
    '      <p>It is being very polite about it, but yes, there is a fresher release waiting on GitHub.</p>' +
    '    </div>' +
    '    <div class="card"><div id="heroLottie"></div></div>' +
    '    <div class="footer"><span class="dot"></span><span>No confetti cannon, but we did bring motion.</span></div>' +
    '  </main>' +
    '  <script src="https://cdnjs.cloudflare.com/ajax/libs/bodymovin/5.12.2/lottie.min.js"></script>' +
    '  <script>' +
    '    (function () {' +
    '      if (!window.lottie) return;' +
    '      var host = document.getElementById("heroLottie");' +
    '      if (!host) return;' +
    '      window.lottie.loadAnimation({' +
    '        container: host,' +
    '        renderer: "svg",' +
    '        loop: true,' +
    '        autoplay: true,' +
    '        path: "https://assets5.lottiefiles.com/packages/lf20_uqaiiqu0.json"' +
    '      });' +
    '    }());' +
    '  </script>' +
    '</body>' +
    '</html>';

function GetUpdateAvailableVisualHtml: string;
begin
  Result := cUpdateAvailableVisualHtml;
end;

end.
