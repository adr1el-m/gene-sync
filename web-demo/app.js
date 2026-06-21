const alphabets = {
  dna: new Set("ATCGN"),
  rna: new Set("AUCG"),
  protein: new Set("ACDEFGHIKLMNPQRSTVWY"),
};

const labels = {
  dna: "DNA",
  rna: "RNA",
  protein: "Protein",
};

const alphabetText = {
  dna: "A, T, C, G, N",
  rna: "A, U, C, G",
  protein: "A, C, D, E, F, G, H, I, K, L, M, N, P, Q, R, S, T, V, W, Y",
};

const MAX_SEQUENCE_LENGTH = 5000;
const MAX_MATRIX_CELLS = 100000;
const MAX_RENDERED_MATRIX_CELLS = 40000;
const MAX_HISTORY_SEQUENCE_PREVIEW = 28;

const presets = {
  normal: {
    kind: "dna",
    sequenceA: "GATTACA",
    sequenceB: "GTCGACG",
    note: "Expected: four substitution candidates.",
  },
  perfect: {
    kind: "dna",
    sequenceA: "ACGTACGT",
    sequenceB: "ACGTACGT",
    note: "Expected: 100% identity and no variant candidates.",
  },
  insertion: {
    kind: "dna",
    sequenceA: "ACGT",
    sequenceB: "ACGTT",
    note: "Expected: an insertion candidate.",
  },
  deletion: {
    kind: "dna",
    sequenceA: "ACGTT",
    sequenceB: "ACGT",
    note: "Expected: a deletion candidate.",
  },
  "invalid-dna": {
    kind: "dna",
    sequenceA: "GATTACA",
    sequenceB: "GTCZACG",
    note: "Expected: invalid DNA letter Z.",
  },
  rna: {
    kind: "rna",
    sequenceA: "AUCGGA",
    sequenceB: "AUUGGA",
    note: "Expected: RNA substitution candidate.",
  },
  protein: {
    kind: "protein",
    sequenceA: "MKTFFV",
    sequenceB: "MKTAFV",
    note: "Expected: protein substitution candidate.",
  },
  "large-matrix": {
    kind: "dna",
    sequenceA: "A".repeat(400),
    sequenceB: "T".repeat(400),
    note: "Expected: blocked by the 100,000-cell matrix cap.",
  },
};

const validationSources = [
  {
    name: "HGVS",
    url: "https://hgvs-nomenclature.org/stable/",
    use: "name the candidate using accepted variant nomenclature",
  },
  {
    name: "Reference Context",
    url: "",
    use: "compare against GeneSync's curated local marker motifs",
  },
  {
    name: "Ensembl VEP",
    url: "https://www.ensembl.org/vep",
    use: "predict the effect after genomic coordinates are known",
  },
  {
    name: "ClinVar",
    url: "https://www.ncbi.nlm.nih.gov/clinvar/intro/",
    use: "provide clinical evidence for curated human marker records",
  },
];

const knownMarkers = [
  {
    organism: "Escherichia coli",
    gene: "gyrA",
    variantName: "gyrA S83L",
    callType: "Evidence-backed AMR marker",
    codon: "TCG → TTG",
    protein: "Ser83Leu / S83L",
    nucleotideChange: "C → T inside the Ser83 codon",
    databaseMatch: "Curated AMR marker record; ClinVar is not primary for this bacterial resistance marker",
    interpretation: "quinolone/fluoroquinolone resistance marker",
    confidence: "High for this submitted fragment because the known gyrA S83L motif is present.",
    referenceMotif: "CATGGTGACTCGGCG",
    variantMotif: "CATGGTGACTTGGCG",
    referenceBase: "C",
    variantBase: "T",
    sourceFindings: [
      {
        name: "Reference context",
        status: "Local motif match",
        detail: "The submitted fragment contains the curated E. coli gyrA Ser83 motif used by GeneSync's local marker database.",
      },
      {
        name: "CARD",
        status: "AMR ontology support",
        detail: "E. coli gyrA point mutations are associated with fluoroquinolone resistance through target alteration.",
      },
      {
        name: "PointFinder",
        status: "Point-mutation validation",
        detail: "PointFinder/ResFinder-style AMR tools are the right validation path for bacterial resistance mutations.",
      },
      {
        name: "ClinVar / VEP",
        status: "Not primary for E. coli",
        detail: "ClinVar and human VEP are not the best evidence sources for this bacterial AMR marker.",
      },
    ],
  },
  {
    markerType: "deletion",
    organism: "Homo sapiens",
    gene: "CFTR",
    variantName: "NM_000492.4(CFTR):c.1520_1522delTCT / c.1521_1523delCTT",
    callType: "Definite known clinical marker",
    codon: "in-frame 3 bp deletion in the Phe508 codon context",
    protein: "p.Phe508del / F508del / deltaF508",
    nucleotideChange: "c.1520_1522delTCT; equivalent CFTR F508del HGVS forms include c.1521_1523delCTT",
    databaseMatch: "ClinVar Variation ID 7105; curated in GeneSync local marker database",
    interpretation: "pathogenic cystic fibrosis-associated CFTR F508del marker",
    confidence:
      "Definite known-marker match for this submitted fragment because the CFTR F508del deletion motif and 3 bp gap are present.",
    referenceMotif: "ATATCATCTTTGGTGTTT",
    variantMotif: "ATATCATTGGTGTTT",
    deletedSequence: "TCT",
    deletionOffset: 6,
    sourceFindings: [
      {
        name: "HGVS",
        status: "Deletion naming",
        detail:
          "The local alignment supports an HGVS in-frame deletion call for CFTR F508del; ClinVar lists MANE forms including c.1520_1522delTCT and c.1521_1523delCTT.",
      },
      {
        name: "Reference context",
        status: "Local motif match",
        detail: "The submitted fragment contains the curated CFTR F508del motif used by GeneSync's local marker database.",
      },
      {
        name: "Ensembl VEP",
        status: "Functional consequence",
        detail: "The expected consequence is an in-frame deletion producing p.Phe508del in CFTR.",
      },
      {
        name: "ClinVar",
        status: "Clinical evidence",
        detail:
          "ClinVar Variation ID 7105 reports CFTR p.Phe508del as a 3 bp deletion with pathogenic cystic fibrosis submissions.",
      },
    ],
  },
  {
    organism: "Homo sapiens",
    gene: "HBB",
    variantName: "NM_000518.5(HBB):c.118C>T",
    callType: "Evidence-backed clinical variant",
    codon: "CAG → TAG",
    protein: "Gln40Ter / Q40*",
    nucleotideChange: "c.118C>T",
    databaseMatch: "ClinVar/HGVS-backed HBB marker record curated in GeneSync local marker database",
    interpretation: "pathogenic beta-thalassemia-associated nonsense variant",
    confidence: "High for this submitted fragment because the known HBB c.118C>T motif is present.",
    referenceMotif: "CCTTGGACCCAGAGGTTC",
    variantMotif: "CCTTGGACCTAGAGGTTC",
    referenceBase: "C",
    variantBase: "T",
    sourceFindings: [
      {
        name: "HGVS",
        status: "Variant naming",
        detail: "HGVS-style transcript notation: NM_000518.5(HBB):c.118C>T, protein p.Gln40Ter.",
      },
      {
        name: "Reference context",
        status: "Local motif match",
        detail: "The submitted fragment contains the curated HBB c.118C>T motif used by GeneSync's local marker database.",
      },
      {
        name: "Ensembl VEP",
        status: "Functional consequence",
        detail: "Expected consequence is a stop-gained/nonsense change in the HBB coding sequence.",
      },
      {
        name: "ClinVar",
        status: "Clinical evidence",
        detail: "ClinVar records NM_000518.5(HBB):c.118C>T (p.Gln40Ter) as pathogenic for beta thalassemia-related conditions.",
      },
    ],
  },
];

const state = {
  kind: "dna",
  result: null,
  history: loadHistory(),
};

let suppressNextDialogRun = false;

const el = {
  sequenceA: document.querySelector("#sequenceA"),
  sequenceB: document.querySelector("#sequenceB"),
  uploadA: document.querySelector("#uploadA"),
  uploadB: document.querySelector("#uploadB"),
  countA: document.querySelector("#countA"),
  countB: document.querySelector("#countB"),
  matchScore: document.querySelector("#matchScore"),
  mismatchScore: document.querySelector("#mismatchScore"),
  gapScore: document.querySelector("#gapScore"),
  hotspotWindow: document.querySelector("#hotspotWindow"),
  hotspotThreshold: document.querySelector("#hotspotThreshold"),
  shuffleIterations: document.querySelector("#shuffleIterations"),
  errorMessage: document.querySelector("#errorMessage"),
  confirmDialog: document.querySelector("#confirmDialog"),
  confirmText: document.querySelector("#confirmText"),
  confirmRun: document.querySelector("#confirmRun"),
};

document.querySelectorAll(".tab").forEach((button) => {
  button.addEventListener("click", () => showScreen(button.dataset.target));
});

document.querySelectorAll(".segment").forEach((button) => {
  button.addEventListener("click", () => {
    setSequenceKind(button.dataset.kind);
  });
});

document.querySelectorAll("[data-preset]").forEach((button) => {
  button.addEventListener("click", () => loadPreset(button.dataset.preset));
});

document.querySelector("#sampleButton").addEventListener("click", loadSample);
document.querySelector("#uploadButtonA").addEventListener("click", () => el.uploadA.click());
document.querySelector("#uploadButtonB").addEventListener("click", () => el.uploadB.click());
el.uploadA.addEventListener("change", () => handleSequenceUpload(el.uploadA, el.sequenceA, "Sequence A"));
el.uploadB.addEventListener("change", () => handleSequenceUpload(el.uploadB, el.sequenceB, "Sequence B"));
document.querySelector("#clearA").addEventListener("click", () => {
  el.sequenceA.value = "";
  updateCounts();
});
document.querySelector("#clearB").addEventListener("click", () => {
  el.sequenceB.value = "";
  updateCounts();
});
document.querySelector("#runButton").addEventListener("click", requestRun);
el.confirmRun.addEventListener("click", (event) => {
  event.preventDefault();
  if (el.confirmDialog.open) {
    suppressNextDialogRun = true;
    el.confirmDialog.close("run");
  }
  executeAlignment();
});
document.querySelector("#printReport").addEventListener("click", () => window.print());
document.querySelector("#clearHistory").addEventListener("click", () => {
  state.history = [];
  saveHistory();
  renderHistory();
});

[el.sequenceA, el.sequenceB].forEach((input) => input.addEventListener("input", updateCounts));

el.confirmDialog.addEventListener("close", () => {
  if (suppressNextDialogRun) {
    suppressNextDialogRun = false;
    return;
  }
  if (el.confirmDialog.returnValue === "run") {
    executeAlignment();
  }
});

updateCounts();
renderHistory();

function showScreen(name) {
  document.querySelectorAll(".screen").forEach((screen) => {
    screen.classList.toggle("active", screen.dataset.screen === name);
  });
  document.querySelectorAll(".tab").forEach((tab) => {
    tab.classList.toggle("active", tab.dataset.target === name);
  });
}

function loadSample() {
  loadPreset("normal");
}

function loadPreset(name) {
  const preset = presets[name];
  if (!preset) return;
  setSequenceKind(preset.kind);
  el.sequenceA.value = preset.sequenceA;
  el.sequenceB.value = preset.sequenceB;
  el.matchScore.value = 1;
  el.mismatchScore.value = -1;
  el.gapScore.value = -2;
  el.hotspotWindow.value = 5;
  el.hotspotThreshold.value = 0.4;
  el.shuffleIterations.value = 100;
  el.errorMessage.textContent = preset.note;
  updateCounts();
  showScreen("align");
}

function setSequenceKind(kind) {
  state.kind = kind;
  document.querySelectorAll(".segment").forEach((button) => {
    button.classList.toggle("active", button.dataset.kind === kind);
  });
}

function handleSequenceUpload(input, target, label) {
  const file = input.files?.[0];
  if (!file) return;

  const allowedExtensions = [".fasta", ".fa", ".fna", ".ffn", ".faa", ".txt"];
  const fileName = file.name.toLowerCase();
  const isAllowed = allowedExtensions.some((extension) => fileName.endsWith(extension)) || file.type === "text/plain";

  if (!isAllowed) {
    el.errorMessage.textContent = `${label} upload must be a .fasta, .fa, .fna, .ffn, .faa, or .txt file.`;
    input.value = "";
    showScreen("align");
    return;
  }

  const reader = new FileReader();
  reader.onload = () => {
    const raw = String(reader.result || "");
    const cleaned = sanitize(raw);
    target.value = raw;
    el.errorMessage.textContent = `${label} loaded from ${file.name}: ${formatNumber(cleaned.length)} cleaned characters.`;
    updateCounts();
    showScreen("align");
    input.value = "";
  };
  reader.onerror = () => {
    el.errorMessage.textContent = `${label} upload failed. Please choose a readable text or FASTA file.`;
    input.value = "";
  };
  reader.readAsText(file);
}

function updateCounts() {
  el.countA.textContent = `${sanitize(el.sequenceA.value).length} chars`;
  el.countB.textContent = `${sanitize(el.sequenceB.value).length} chars`;
}

function requestRun() {
  el.errorMessage.textContent = "";
  const sequenceA = sanitize(el.sequenceA.value);
  const sequenceB = sanitize(el.sequenceB.value);
  const scoring = readScoring();
  const cells = matrixCellCount(sequenceA, sequenceB);

  const validationError = validateInput(sequenceA, sequenceB, scoring);
  if (validationError) {
    el.errorMessage.textContent = validationError;
    return;
  }

  el.confirmText.textContent =
    `GeneSync will align ${sequenceA.length} x ${sequenceB.length} ${labels[state.kind]} characters ` +
    `using match ${scoring.match}, mismatch ${scoring.mismatch}, and gap ${scoring.gap}. ` +
    `The dynamic programming matrix will contain ${formatNumber(cells)} cells.`;

  if (typeof el.confirmDialog.showModal === "function") {
    el.confirmDialog.showModal();
  } else if (window.confirm(el.confirmText.textContent)) {
    executeAlignment();
  }
}

function readScoring() {
  return {
    rawMatch: el.matchScore.value,
    rawMismatch: el.mismatchScore.value,
    rawGap: el.gapScore.value,
    match: Number(el.matchScore.value),
    mismatch: Number(el.mismatchScore.value),
    gap: Number(el.gapScore.value),
  };
}

function sanitize(raw) {
  return raw
    .split(/\r?\n/)
    .filter((line) => !line.trim().startsWith(">"))
    .join("")
    .toUpperCase()
    .replace(/[^A-Z]/g, "");
}

function validateInput(sequenceA, sequenceB, scoring) {
  if (!sequenceA || !sequenceB) return "Both sequences must contain biological characters.";
  if (sequenceA.length > MAX_SEQUENCE_LENGTH || sequenceB.length > MAX_SEQUENCE_LENGTH) {
    return `Each sequence is limited to ${formatNumber(MAX_SEQUENCE_LENGTH)} characters.`;
  }
  const cells = matrixCellCount(sequenceA, sequenceB);
  if (cells > MAX_MATRIX_CELLS) {
    return (
      `This comparison would create ${formatNumber(cells)} matrix cells. ` +
      `The web demo limit is ${formatNumber(MAX_MATRIX_CELLS)} cells, so use shorter subsequences for testing.`
    );
  }
  if (
    !scoring.rawMatch.trim() ||
    !scoring.rawMismatch.trim() ||
    !scoring.rawGap.trim() ||
    !Number.isFinite(scoring.match) ||
    !Number.isFinite(scoring.mismatch) ||
    !Number.isFinite(scoring.gap)
  ) {
    return "Match, mismatch, and gap must be valid numbers.";
  }
  if (scoring.match <= scoring.mismatch || scoring.gap >= 0) {
    return "Match must be greater than mismatch, and gap must be negative.";
  }
  const allowed = alphabets[state.kind];
  const invalidA = invalidCharacters(sequenceA, allowed);
  if (invalidA.length) {
    return `Sequence A has invalid ${labels[state.kind]} letters: ${invalidA.join(", ")}. Allowed: ${alphabetText[state.kind]}.`;
  }
  const invalidB = invalidCharacters(sequenceB, allowed);
  if (invalidB.length) {
    return `Sequence B has invalid ${labels[state.kind]} letters: ${invalidB.join(", ")}. Allowed: ${alphabetText[state.kind]}.`;
  }
  return "";
}

function invalidCharacters(sequence, allowed) {
  return [...new Set([...sequence].filter((char) => !allowed.has(char)))];
}

function matrixCellCount(sequenceA, sequenceB) {
  return (sequenceA.length + 1) * (sequenceB.length + 1);
}

function findKnownMarkers(sequenceA, sequenceB, candidates) {
  return knownMarkers
    .map((marker) => {
      const referenceIndex = sequenceA.indexOf(marker.referenceMotif);
      const variantIndex = sequenceB.indexOf(marker.variantMotif);
      if (referenceIndex < 0 || variantIndex < 0) return null;

      const candidate =
        marker.markerType === "deletion"
          ? findDeletionMarkerCandidate(marker, referenceIndex, candidates)
          : findSubstitutionMarkerCandidate(marker, referenceIndex, candidates);

      if (!candidate) return null;

      return {
        ...marker,
        position: candidate.position,
      };
    })
    .filter(Boolean);
}

function findSubstitutionMarkerCandidate(marker, referenceIndex, candidates) {
  const markerOffset = marker.referenceMotif
    .split("")
    .findIndex((char, index) => char !== marker.variantMotif[index]);
  const expectedPosition = markerOffset >= 0 ? referenceIndex + markerOffset + 1 : 0;

  if (markerOffset < 0) return null;

  return candidates.find(
    (item) =>
      item.type.startsWith("Substitution") &&
      numericPosition(item.position) === expectedPosition &&
      item.reference === marker.referenceBase &&
      item.variant === marker.variantBase,
  );
}

function findDeletionMarkerCandidate(marker, referenceIndex, candidates) {
  const expectedPosition = referenceIndex + marker.deletionOffset + 1;

  return candidates.find(
    (item) =>
      item.type.startsWith("Deletion") &&
      numericPosition(item.position) === expectedPosition &&
      item.reference === marker.deletedSequence &&
      item.variant === "-",
  );
}

function executeAlignment() {
  try {
    runAlignment();
  } catch (error) {
    console.error(error);
    el.errorMessage.textContent = `Run failed: ${error.message}`;
    showScreen("align");
  }
}

function runAlignment() {
  const started = performance.now();
  const sequenceA = sanitize(el.sequenceA.value);
  const sequenceB = sanitize(el.sequenceB.value);
  const scoring = readScoring();
  const rows = sequenceA.length + 1;
  const columns = sequenceB.length + 1;
  const matrix = Array.from({ length: rows }, () => Array(columns).fill(0));
  const moves = Array.from({ length: rows }, () => Array(columns).fill("none"));

  for (let row = 1; row < rows; row++) {
    matrix[row][0] = row * scoring.gap;
    moves[row][0] = "up";
  }
  for (let column = 1; column < columns; column++) {
    matrix[0][column] = column * scoring.gap;
    moves[0][column] = "left";
  }

  for (let row = 1; row < rows; row++) {
    for (let column = 1; column < columns; column++) {
      const substitution = sequenceA[row - 1] === sequenceB[column - 1] ? scoring.match : scoring.mismatch;
      const diagonal = matrix[row - 1][column - 1] + substitution;
      const up = matrix[row - 1][column] + scoring.gap;
      const left = matrix[row][column - 1] + scoring.gap;

      if (diagonal >= up && diagonal >= left) {
        matrix[row][column] = diagonal;
        moves[row][column] = "diagonal";
      } else if (up >= left) {
        matrix[row][column] = up;
        moves[row][column] = "up";
      } else {
        matrix[row][column] = left;
        moves[row][column] = "left";
      }
    }
  }

  let row = sequenceA.length;
  let column = sequenceB.length;
  const alignedA = [];
  const alignedB = [];
  const path = [];

  while (row > 0 || column > 0) {
    path.push([row, column]);
    const move = moves[row][column];
    if (move === "diagonal" && row > 0 && column > 0) {
      alignedA.push(sequenceA[row - 1]);
      alignedB.push(sequenceB[column - 1]);
      row -= 1;
      column -= 1;
    } else if (move === "up" && row > 0) {
      alignedA.push(sequenceA[row - 1]);
      alignedB.push("-");
      row -= 1;
    } else {
      alignedA.push("-");
      alignedB.push(sequenceB[column - 1]);
      column -= 1;
    }
  }
  path.push([0, 0]);
  path.reverse();
  alignedA.reverse();
  alignedB.reverse();

  const alignmentA = alignedA.join("");
  const alignmentB = alignedB.join("");
  const identity = computeIdentity(alignedA, alignedB);
  const hotspots = findHotspots(alignedA, alignedB);
  const variantCandidates = findVariantCandidates(alignedA, alignedB);
  const markerAnnotations = findKnownMarkers(sequenceA, sequenceB, variantCandidates);
  const significance = evaluateSignificance(sequenceA, sequenceB, scoring, matrix[rows - 1][columns - 1]);

  state.result = {
    createdAt: new Date().toISOString(),
    sequenceA,
    sequenceB,
    kind: state.kind,
    scoring,
    matrix,
    moves,
    rows,
    columns,
    path,
    alignedA: alignmentA,
    alignedB: alignmentB,
    score: matrix[rows - 1][columns - 1],
    identity,
    hotspots,
    variantCandidates,
    markerAnnotations,
    significance,
    duration: (performance.now() - started) / 1000,
  };

  addHistory(state.result);
  renderAll();
  showScreen("results");
}

function computeIdentity(alignedA, alignedB) {
  const matches = alignedA.filter((char, index) => char === alignedB[index]).length;
  return alignedA.length ? (matches / alignedA.length) * 100 : 0;
}

function findVariantCandidates(alignedA, alignedB) {
  const candidates = [];
  let referencePosition = 0;
  let variantPosition = 0;
  let index = 0;

  while (index < alignedA.length) {
    const top = alignedA[index];
    const bottom = alignedB[index];

    if (top !== "-" && bottom !== "-" && top === bottom) {
      referencePosition += 1;
      variantPosition += 1;
      index += 1;
      continue;
    }

    if (top === "-") {
      const inserted = [];
      const startsAfterReference = referencePosition;
      const variantStart = variantPosition + 1;
      while (index < alignedA.length && alignedA[index] === "-" && alignedB[index] !== "-") {
        inserted.push(alignedB[index]);
        variantPosition += 1;
        index += 1;
      }
      candidates.push({
        type: "Insertion candidate",
        position: startsAfterReference === 0 ? "before ref 1" : `after ref ${startsAfterReference}`,
        variantPosition: inserted.length === 1 ? `var ${variantStart}` : `var ${variantStart}-${variantPosition}`,
        reference: "-",
        variant: inserted.join(""),
        validation: "HGVS insertion naming, reference-context check, VEP effect, ClinVar evidence if human",
      });
      continue;
    }

    if (bottom === "-") {
      const deleted = [];
      const referenceStart = referencePosition + 1;
      while (index < alignedA.length && alignedA[index] !== "-" && alignedB[index] === "-") {
        deleted.push(alignedA[index]);
        referencePosition += 1;
        index += 1;
      }
      candidates.push({
        type: "Deletion candidate",
        position: deleted.length === 1 ? `ref ${referenceStart}` : `ref ${referenceStart}-${referencePosition}`,
        variantPosition: variantPosition === 0 ? "before var 1" : `after var ${variantPosition}`,
        reference: deleted.join(""),
        variant: "-",
        validation: "HGVS deletion naming, reference-context check, VEP effect, ClinVar evidence if human",
      });
      continue;
    }

    referencePosition += 1;
    variantPosition += 1;
    candidates.push({
      type: "Substitution candidate",
      position: `ref ${referencePosition}`,
      variantPosition: `var ${variantPosition}`,
      reference: top,
      variant: bottom,
      validation: "HGVS substitution naming, reference-context check, VEP effect, ClinVar evidence if human",
    });
    index += 1;
  }

  return candidates;
}

function findHotspots(alignedA, alignedB) {
  const windowSize = Math.min(Math.max(Number(el.hotspotWindow.value), 2), alignedA.length);
  const threshold = Number(el.hotspotThreshold.value);
  const hotspots = [];
  for (let start = 0; start <= alignedA.length - windowSize; start++) {
    const end = start + windowSize;
    let gaps = 0;
    let mismatches = 0;
    for (let index = start; index < end; index++) {
      if (alignedA[index] === "-" || alignedB[index] === "-") gaps += 1;
      else if (alignedA[index] !== alignedB[index]) mismatches += 1;
    }
    const density = (gaps + mismatches) / windowSize;
    if (density >= threshold) {
      hotspots.push({ start: start + 1, end, density, gaps, mismatches });
    }
  }
  return mergeHotspots(hotspots);
}

function mergeHotspots(hotspots) {
  if (!hotspots.length) return [];
  const merged = [];
  let current = { ...hotspots[0] };
  for (const hotspot of hotspots.slice(1)) {
    if (hotspot.start <= current.end) {
      current = {
        start: current.start,
        end: Math.max(current.end, hotspot.end),
        density: Math.max(current.density, hotspot.density),
        gaps: Math.max(current.gaps, hotspot.gaps),
        mismatches: Math.max(current.mismatches, hotspot.mismatches),
      };
    } else {
      merged.push(current);
      current = { ...hotspot };
    }
  }
  merged.push(current);
  return merged;
}

function evaluateSignificance(sequenceA, sequenceB, scoring, originalScore) {
  const requested = Math.max(1, Math.min(Number(el.shuffleIterations.value), 100));
  const scores = [];
  let seed = 0x47534e59;
  for (let index = 0; index < requested; index++) {
    const shuffled = shuffle([...sequenceB], () => {
      seed = (seed * 1664525 + 1013904223) >>> 0;
      return seed / 2 ** 32;
    });
    scores.push(scoreOnly([...sequenceA], shuffled, scoring));
  }
  const mean = scores.reduce((sum, score) => sum + score, 0) / scores.length;
  const variance = scores.reduce((sum, score) => sum + (score - mean) ** 2, 0) / scores.length;
  const standardDeviation = Math.sqrt(variance);
  const zScore = standardDeviation > 0 ? (originalScore - mean) / standardDeviation : 0;
  const moreOrEqual = scores.filter((score) => score >= originalScore).length;
  const pValue = (moreOrEqual + 1) / (scores.length + 1);
  return {
    requestedIterations: requested,
    iterations: scores.length,
    meanScore: mean,
    standardDeviation,
    zScore,
    pValue,
    significant: pValue <= 0.05 && zScore >= 1.96,
  };
}

function shuffle(values, random) {
  for (let index = values.length - 1; index > 0; index--) {
    const target = Math.floor(random() * (index + 1));
    [values[index], values[target]] = [values[target], values[index]];
  }
  return values;
}

function scoreOnly(sequenceA, sequenceB, scoring) {
  const columns = sequenceB.length + 1;
  let previous = Array(columns).fill(0);
  let current = Array(columns).fill(0);
  for (let column = 1; column < columns; column++) previous[column] = column * scoring.gap;
  for (let row = 1; row <= sequenceA.length; row++) {
    current[0] = row * scoring.gap;
    for (let column = 1; column < columns; column++) {
      const substitution = sequenceA[row - 1] === sequenceB[column - 1] ? scoring.match : scoring.mismatch;
      current[column] = Math.max(
        previous[column - 1] + substitution,
        previous[column] + scoring.gap,
        current[column - 1] + scoring.gap,
      );
    }
    [previous, current] = [current, previous];
  }
  return previous[columns - 1];
}

function renderAll() {
  renderMatrix();
  renderResults();
  renderHistory();
}

function renderMatrix() {
  const empty = document.querySelector("#matrixEmpty");
  const content = document.querySelector("#matrixContent");
  if (!state.result) {
    empty.classList.remove("hidden");
    content.classList.add("hidden");
    return;
  }
  empty.classList.add("hidden");
  content.classList.remove("hidden");

  document.querySelector("#matrixMetrics").innerHTML = [
    metric("Rows", state.result.rows, "Sequence A prefixes"),
    metric("Columns", state.result.columns, "Sequence B prefixes"),
    metric("Final Score", state.result.score, "F(m,n)"),
    metric("Cells", formatNumber(state.result.rows * state.result.columns), "Matrix size"),
  ].join("");

  const table = document.querySelector("#matrixTable");
  const cellCount = state.result.rows * state.result.columns;
  if (cellCount > MAX_RENDERED_MATRIX_CELLS) {
    table.innerHTML = `
      <tbody>
        <tr>
          <td class="matrix-message">
            Matrix rendering is capped at ${formatNumber(MAX_RENDERED_MATRIX_CELLS)} cells.
            This run produced ${formatNumber(cellCount)} cells, so GeneSync computed the score
            and traceback but skipped the full table view to keep the browser responsive.
          </td>
        </tr>
      </tbody>
    `;
    return;
  }

  const pathSet = new Set(state.result.path.map(([row, column]) => `${row}:${column}`));
  let html = "<thead><tr><th></th><th>0</th>";
  for (const char of state.result.sequenceB) html += `<th>${char}</th>`;
  html += "</tr></thead><tbody>";
  for (let row = 0; row < state.result.rows; row++) {
    html += `<tr><th>${row === 0 ? "0" : state.result.sequenceA[row - 1]}</th>`;
    for (let column = 0; column < state.result.columns; column++) {
      const isTrace = pathSet.has(`${row}:${column}`);
      html += `<td class="${isTrace ? "trace" : ""}">${state.result.matrix[row][column]}</td>`;
    }
    html += "</tr>";
  }
  table.innerHTML = `${html}</tbody>`;
}

function renderResults() {
  const empty = document.querySelector("#resultsEmpty");
  const content = document.querySelector("#resultsContent");
  if (!state.result) {
    empty.classList.remove("hidden");
    content.classList.add("hidden");
    return;
  }
  empty.classList.add("hidden");
  content.classList.remove("hidden");

  document.querySelector("#resultMetrics").innerHTML = [
    metric("Score", state.result.score, "Needleman-Wunsch"),
    metric("Identity", `${state.result.identity.toFixed(1)}%`, "Alignment matches"),
    metric("P Value", state.result.significance.pValue.toFixed(3), `${state.result.significance.iterations} shuffles`),
    metric("Cells", formatNumber(state.result.rows * state.result.columns), `${state.result.duration.toFixed(3)}s runtime`),
  ].join("");

  renderAlignment();
  renderVariantCandidates();
  renderSignificance();
  renderHotspots();
}

function renderAlignment() {
  const container = document.querySelector("#alignmentView");
  const columns = [...state.result.alignedA].map((top, index) => {
    const bottom = state.result.alignedB[index];
    let mode = "mismatch";
    let symbol = "•";
    if (top === "-" || bottom === "-") {
      mode = "gap";
      symbol = "−";
    } else if (top === bottom) {
      mode = "match";
      symbol = "|";
    }
    return `
      <div class="alignment-column">
        <div class="letter-cell">${top}</div>
        <div class="connector ${mode}">${symbol}</div>
        <div class="letter-cell">${bottom}</div>
        <div class="position-label">${index + 1}</div>
      </div>
    `;
  });
  container.innerHTML = `<div class="alignment-row">${columns.join("")}</div>`;
}

function renderVariantCandidates() {
  const view = document.querySelector("#variantCandidateView");
  const candidates = state.result.variantCandidates || [];
  const markers = state.result.markerAnnotations || [];
  const title = document.querySelector("#variantPanelTitle");
  const note = document.querySelector("#variantPanelNote");
  const sourceLinks = validationSources
    .map((source) =>
      source.url
        ? `<a href="${source.url}" target="_blank" rel="noopener">${source.name}</a>`
        : `<span>${source.name}</span>`,
    )
    .join("");

  if (title && note) {
    if (markers.length) {
      title.textContent = "Known Variant Result";
      note.textContent =
        "GeneSync matched the submitted alignment to a curated marker pattern and reports a definite known-marker result for these strings.";
    } else if (candidates.length) {
      title.textContent = "Variant Candidates";
      note.textContent =
        "GeneSync found definite alignment differences. Unmatched rows stay as candidates until a curated marker pattern is available.";
    } else {
      title.textContent = "Variant Result";
      note.textContent = "GeneSync found no mismatches or gaps in the submitted alignment.";
    }
  }

  const sourcePanel = `
    <div class="validation-strip" aria-label="Recommended validation sources">
      ${sourceLinks}
    </div>
  `;

  if (!candidates.length) {
    view.innerHTML = `
      ${sourcePanel}
      <div class="candidate-empty">
        <strong>No candidate variation detected.</strong>
        <span>GeneSync found no mismatches or gaps in the submitted alignment.</span>
      </div>
    `;
    return;
  }

  const primaryInterpretation = buildCandidateInterpretation(candidates, state.result.markerAnnotations || []);
  const rows = candidates
    .map(
      (candidate, index) => {
        const detail = describeCandidate(candidate);
        return `
        <tr>
          <td>${index + 1}</td>
          <td>${candidate.type}</td>
          <td>${candidate.position}</td>
          <td>${candidate.reference}</td>
          <td>${candidate.variant}</td>
          <td>${detail.evidence}</td>
          <td>${detail.context}</td>
          <td>${candidate.validation}</td>
        </tr>
      `;
      },
    )
    .join("");

  view.innerHTML = `
    ${sourcePanel}
    <div class="interpretation-card">
      <strong>${primaryInterpretation.title}</strong>
      <p>${primaryInterpretation.body}</p>
      <div class="interpretation-grid">
        ${resultRow("Alignment call", primaryInterpretation.call)}
        ${resultRow("Confidence", primaryInterpretation.confidence)}
        ${resultRow("Biological status", primaryInterpretation.status)}
      </div>
    </div>
    ${renderMarkerAnnotations()}
    <div class="candidate-summary">
      <strong>${candidates.length}</strong>
      <span>${candidates.length === 1 ? "difference" : "differences"} detected by Needleman-Wunsch traceback.</span>
    </div>
    <div class="candidate-table-scroll">
      <table class="candidate-table">
        <thead>
          <tr>
            <th>#</th>
            <th>Type</th>
            <th>Reference Position</th>
            <th>Ref</th>
            <th>Variant</th>
            <th>Alignment Evidence</th>
            <th>Local Context</th>
            <th>Validation Basis</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
  `;
}

function renderMarkerAnnotations() {
  const markers = state.result.markerAnnotations || [];
  if (!markers.length) return "";

  return markers
    .map((marker) => {
      const sourceRows = marker.sourceFindings
        .map(
          (source) => `
            <article class="evidence-card">
              <strong>${source.name}</strong>
              <span>${source.status}</span>
              <p>${source.detail}</p>
            </article>
          `,
        )
    .join("");
      return `
        <div class="marker-card">
          <span class="marker-kicker">${marker.callType}</span>
          <strong>${marker.variantName}</strong>
          <p>${marker.confidence}</p>
          <div class="marker-grid">
            ${resultRow("Organism", marker.organism)}
            ${resultRow("Gene", marker.gene)}
            ${resultRow("Database match", marker.databaseMatch)}
            ${resultRow("Nucleotide", marker.nucleotideChange)}
            ${resultRow("Codon", marker.codon)}
            ${resultRow("Protein", marker.protein)}
            ${resultRow("Detected position", marker.position)}
            ${resultRow("Local context", markerLocalContext(marker, 8))}
            ${resultRow("Interpretation", marker.interpretation)}
          </div>
          <div class="evidence-grid">${sourceRows}</div>
        </div>
      `;
    })
    .join("");
}

function buildCandidateInterpretation(candidates, markers) {
  const substitutions = candidates.filter((candidate) => candidate.type.startsWith("Substitution")).length;
  const insertions = candidates.filter((candidate) => candidate.type.startsWith("Insertion")).length;
  const deletions = candidates.filter((candidate) => candidate.type.startsWith("Deletion")).length;
  const parts = [];
  if (substitutions) parts.push(`${substitutions} substitution${substitutions === 1 ? "" : "s"}`);
  if (insertions) parts.push(`${insertions} insertion${insertions === 1 ? "" : "s"}`);
  if (deletions) parts.push(`${deletions} deletion${deletions === 1 ? "" : "s"}`);

  if (markers.length) {
    return {
      title: "Definite known marker result",
      call: markers.map((marker) => marker.variantName).join(", "),
      confidence: "Definite known-marker match for the submitted strings",
      status: "Curated database marker matched",
      body:
        `GeneSync found ${parts.join(", ")} and matched the change against GeneSync's curated marker database. ` +
        "The alignment event and marker annotation below explain the gene, nucleotide call, protein effect, and validation evidence.",
    };
  }

  return {
    title: "Definite alignment difference detected",
    call: parts.join(", "),
    confidence: "Definite alignment difference only",
    status: "Not found in the current local marker database",
    body:
      `GeneSync found ${parts.join(", ")} between Sequence A and Sequence B. ` +
      "This is a definite difference in the submitted strings, but GeneSync did not match it to a curated marker database record.",
  };
}

function describeCandidate(candidate) {
  if (candidate.type.startsWith("Substitution")) {
    const position = numericPosition(candidate.position);
    return {
      evidence: `${candidate.reference} is aligned directly against ${candidate.variant} at the same column.`,
      context: localContext(position, 8),
    };
  }
  if (candidate.type.startsWith("Insertion")) {
    return {
      evidence: `${candidate.variant} appears opposite a gap in Sequence A.`,
      context: `Inserted segment: ${candidate.variant}`,
    };
  }
  return {
    evidence: `${candidate.reference} appears opposite a gap in Sequence B.`,
    context: `Deleted reference segment: ${candidate.reference}`,
  };
}

function numericPosition(positionText) {
  const match = positionText.match(/\d+/);
  return match ? Number(match[0]) : 0;
}

function localContext(position, flank) {
  if (!position) return "Context unavailable";
  const start = Math.max(position - flank - 1, 0);
  const end = Math.min(position + flank, state.result.sequenceA.length);
  const localIndex = position - 1 - start;
  const reference = state.result.sequenceA.slice(start, end);
  if (!reference) return "Context unavailable";
  const candidate = state.result.variantCandidates.find((item) => numericPosition(item.position) === position);
  const variantBase = candidate ? candidate.variant : "?";
  return `${reference.slice(0, localIndex)}[${reference[localIndex]}→${variantBase}]${reference.slice(localIndex + 1)}`;
}

function markerLocalContext(marker, flank) {
  const position = numericPosition(marker.position);
  if (!state.result || !position) return "Context unavailable";

  if (marker.markerType === "deletion" && marker.deletedSequence) {
    const deletionStart = position - 1;
    const deletionEnd = deletionStart + marker.deletedSequence.length;
    const start = Math.max(deletionStart - flank, 0);
    const end = Math.min(deletionEnd + flank, state.result.sequenceA.length);
    const reference = state.result.sequenceA;

    return `${reference.slice(start, deletionStart)}[${reference.slice(deletionStart, deletionEnd)}→-]${reference.slice(deletionEnd, end)}`;
  }

  return localContext(position, flank);
}

function renderSignificance() {
  const sig = state.result.significance;
  document.querySelector("#significanceView").innerHTML = [
    resultRow("Requested shuffles", sig.requestedIterations),
    resultRow("Effective shuffles", sig.iterations),
    resultRow("Mean shuffled score", sig.meanScore.toFixed(2)),
    resultRow("Standard deviation", sig.standardDeviation.toFixed(2)),
    resultRow("Z score", sig.zScore.toFixed(2)),
    resultRow("Assessment", sig.significant ? "Significant" : "Needs review"),
  ].join("");
}

function renderHotspots() {
  const view = document.querySelector("#hotspotView");
  const length = state.result.alignedA.length;
  const active = Array(length).fill(false);
  for (const hotspot of state.result.hotspots) {
    for (let index = hotspot.start - 1; index < hotspot.end; index++) active[index] = true;
  }
  const bar = `<div class="hotspot-bar">${active
    .map((flag) => `<span class="hotspot-segment ${flag ? "active" : ""}"></span>`)
    .join("")}</div>`;
  const rows = state.result.hotspots.length
    ? state.result.hotspots
        .map((hotspot) =>
          resultRow(
            `Positions ${hotspot.start}-${hotspot.end}`,
            `${(hotspot.density * 100).toFixed(1)}%, ${hotspot.gaps} gaps, ${hotspot.mismatches} mismatches`,
          ),
        )
        .join("")
    : `<p>No windows crossed the selected density threshold.</p>`;
  view.innerHTML = `${bar}<div class="result-list" style="margin-top: 12px">${rows}</div>`;
}

function metric(title, value, detail) {
  return `
    <div class="metric-card">
      <div class="metric-title">${title}</div>
      <div class="metric-value">${value}</div>
      <div class="metric-detail">${detail}</div>
    </div>
  `;
}

function resultRow(title, value) {
  return `<div class="result-row"><span>${title}</span><strong>${value}</strong></div>`;
}

function addHistory(result) {
  state.history = [
    {
      createdAt: result.createdAt,
      kind: result.kind,
      sequenceA: result.sequenceA,
      sequenceB: result.sequenceB,
      score: result.score,
      identity: result.identity,
    },
    ...state.history.filter((item) => item.sequenceA !== result.sequenceA || item.sequenceB !== result.sequenceB),
  ].slice(0, 20);
  saveHistory();
}

function renderHistory() {
  const list = document.querySelector("#historyList");
  if (!state.history.length) {
    list.innerHTML = `<p>Completed alignments are saved locally in this browser.</p>`;
    return;
  }
  list.innerHTML = state.history
    .map(
      (item) => `
      <button class="history-card" type="button" data-created-at="${item.createdAt}">
        <span>
          <strong>${new Date(item.createdAt).toLocaleString()}</strong><br />
          ${labels[item.kind]} · ${sequencePreview(item.sequenceA)} / ${sequencePreview(item.sequenceB)}
        </span>
        <strong>${item.score} · ${item.identity.toFixed(1)}%</strong>
      </button>
    `,
    )
    .join("");
}

function loadHistory() {
  try {
    return JSON.parse(localStorage.getItem("genesync.web.history") || "[]");
  } catch {
    return [];
  }
}

function saveHistory() {
  localStorage.setItem("genesync.web.history", JSON.stringify(state.history));
}

function sequencePreview(sequence) {
  if (sequence.length <= MAX_HISTORY_SEQUENCE_PREVIEW) return sequence;
  return `${sequence.slice(0, MAX_HISTORY_SEQUENCE_PREVIEW)}...${sequence.length} chars`;
}

function formatNumber(value) {
  return new Intl.NumberFormat("en-US").format(value);
}
