import fs from "node:fs/promises";
import path from "node:path";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const REPORT_DIR =
  "/Users/ubdbd/Desktop/연구실/범불안장애 DTx/Lab_test/analytics_report/final_comprehensive";
const CHART_DIR = path.join(REPORT_DIR, "charts");

const FINAL_PPTX =
  process.env.FINAL_PPTX ??
  path.resolve("outputs/mindrium_final_comprehensive_presentation.pptx");
const PREVIEW_DIR =
  process.env.PREVIEW_DIR ?? path.resolve("outputs/mindrium_final_presentation_preview");
const QA_DIR =
  process.env.QA_DIR ?? path.resolve("outputs/mindrium_final_presentation_qa");

const W = 1280;
const H = 720;
const PAGE = { left: 66, top: 54, width: 1148, height: 612 };

const C = {
  bg: "#F7F8F4",
  paper: "#FFFFFF",
  ink: "#162033",
  muted: "#64748B",
  line: "#D7DEE8",
  navy: "#1B2A41",
  teal: "#0F766E",
  tealSoft: "#DDF4EF",
  blue: "#2563EB",
  blueSoft: "#E7EEF9",
  coral: "#E76F51",
  coralSoft: "#FBEAE4",
  amber: "#D97706",
  amberSoft: "#FFF0D6",
  green: "#15803D",
  greenSoft: "#E4F4E9",
  graySoft: "#EDF1F5",
};

const noLine = { style: "solid", fill: "none", width: 0 };
const thinLine = { style: "solid", fill: C.line, width: 1 };

async function writeBlob(filePath, blob) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, new Uint8Array(await blob.arrayBuffer()));
}

function chart(name) {
  return path.join(CHART_DIR, name);
}

async function readPng(name) {
  return await fs.readFile(chart(name));
}

async function readCsv(filePath) {
  const text = await fs.readFile(filePath, "utf8");
  const lines = text.replace(/^\uFEFF/, "").trim().split(/\r?\n/).filter(Boolean);
  if (lines.length === 0) return [];
  const headers = lines[0].split(",");
  return lines.slice(1).map((line) => {
    const values = line.split(",");
    const row = {};
    headers.forEach((header, idx) => {
      row[header] = values[idx] ?? "";
    });
    return row;
  });
}

function num(value) {
  const cleaned = String(value ?? "").replace(/,/g, "");
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : 0;
}

function oneDecimal(value) {
  return Number(value).toFixed(1);
}

function addText(slide, text, position, options = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position,
    fill: "none",
    line: noLine,
  });
  shape.text = text;
  shape.text.style = {
    fontSize: options.fontSize ?? 20,
    bold: options.bold ?? false,
    color: options.color ?? C.ink,
    alignment: options.alignment ?? "left",
  };
  return shape;
}

function addSectionLabel(slide, label, position = { left: PAGE.left, top: 42, width: 210, height: 28 }) {
  const pill = slide.shapes.add({
    geometry: "roundRect",
    position,
    fill: C.tealSoft,
    line: { style: "solid", fill: "#B5DDD6", width: 1 },
    borderRadius: 14,
  });
  pill.text = label;
  pill.text.style = {
    fontSize: 14,
    bold: true,
    color: C.teal,
    alignment: "center",
  };
  return pill;
}

function addTitle(slide, title, subtitle, section) {
  addSectionLabel(slide, section);
  addText(slide, title, { left: PAGE.left, top: 78, width: 900, height: 52 }, {
    fontSize: 35,
    bold: true,
    color: C.ink,
  });
  if (subtitle) {
    addText(slide, subtitle, { left: PAGE.left, top: 132, width: 940, height: 42 }, {
      fontSize: 18,
      color: C.muted,
    });
  }
}

function addFooter(slide, index) {
  addText(slide, "Mindrium 8주 완료 데이터 분석", {
    left: PAGE.left,
    top: 676,
    width: 360,
    height: 22,
  }, { fontSize: 12, color: "#93A1B2" });
  addText(slide, String(index).padStart(2, "0"), {
    left: 1166,
    top: 674,
    width: 48,
    height: 24,
  }, { fontSize: 12, bold: true, color: "#93A1B2", alignment: "right" });
}

function addCard(slide, position, fill = C.paper, line = thinLine) {
  return slide.shapes.add({
    geometry: "roundRect",
    position,
    fill,
    line,
    borderRadius: 18,
    shadow: "shadow-sm",
  });
}

function addMetric(slide, { x, y, w, h, value, label, note, color = C.teal, fill = C.paper }) {
  addCard(slide, { left: x, top: y, width: w, height: h }, fill);
  slide.shapes.add({
    geometry: "rect",
    position: { left: x, top: y, width: 7, height: h },
    fill: color,
    line: noLine,
  });
  if (h < 126) {
    addText(slide, value, { left: x + 24, top: y + 16, width: w - 40, height: 36 }, {
      fontSize: 31,
      bold: true,
      color,
    });
    addText(slide, label, { left: x + 24, top: y + 56, width: w - 40, height: 28 }, {
      fontSize: 17,
      bold: true,
      color: C.ink,
    });
    if (note && h >= 116) {
      addText(slide, note, { left: x + 24, top: y + 88, width: w - 40, height: 24 }, {
        fontSize: 13,
        color: C.muted,
      });
    }
  } else {
    addText(slide, value, { left: x + 24, top: y + 18, width: w - 40, height: 46 }, {
      fontSize: 34,
      bold: true,
      color,
    });
    addText(slide, label, { left: x + 24, top: y + 68, width: w - 40, height: 34 }, {
      fontSize: 18,
      bold: true,
      color: C.ink,
    });
    if (note) {
      addText(slide, note, { left: x + 24, top: y + 106, width: w - 40, height: 46 }, {
        fontSize: 15,
        color: C.muted,
      });
    }
  }
}

async function addChart(slide, imageName, position, alt, fit = "contain") {
  slide.images.add({
    blob: await readPng(imageName),
    contentType: "image/png",
    alt,
    fit,
    position,
    geometry: "roundRect",
    borderRadius: 12,
  });
}

async function addChartCard(slide, imageName, position, alt) {
  addCard(slide, position);
  await addChart(slide, imageName, {
    left: position.left + 14,
    top: position.top + 14,
    width: position.width - 28,
    height: position.height - 28,
  }, alt);
}

function addInsightBox(slide, title, body, position, color = C.teal, fill = C.tealSoft) {
  addCard(slide, position, fill, { style: "solid", fill: `${color}`, width: 1 });
  addText(slide, title, {
    left: position.left + 22,
    top: position.top + 18,
    width: position.width - 44,
    height: 32,
  }, { fontSize: 21, bold: true, color });
  addText(slide, body, {
    left: position.left + 22,
    top: position.top + 58,
    width: position.width - 44,
    height: position.height - 72,
  }, { fontSize: 17, color: C.ink });
}

function addBullet(slide, text, x, y, width, accent = C.teal) {
  slide.shapes.add({
    geometry: "ellipse",
    position: { left: x, top: y + 8, width: 9, height: 9 },
    fill: accent,
    line: noLine,
  });
  addText(slide, text, { left: x + 22, top: y, width, height: 48 }, {
    fontSize: 18,
    color: C.ink,
  });
}

function addContextRow(slide, rank, place, time, count, sud, y) {
  const colors = [C.coral, C.amber, C.teal];
  const accent = colors[(rank - 1) % colors.length];
  slide.shapes.add({
    geometry: "roundRect",
    position: { left: 724, top: y, width: 448, height: 48 },
    fill: rank <= 3 ? C.coralSoft : C.paper,
    line: thinLine,
    borderRadius: 14,
  });
  addText(slide, String(rank), { left: 746, top: y + 11, width: 28, height: 24 }, {
    fontSize: 16,
    bold: true,
    color: accent,
    alignment: "center",
  });
  addText(slide, `${place} · ${time}`, { left: 792, top: y + 10, width: 174, height: 26 }, {
    fontSize: 17,
    bold: true,
    color: C.ink,
  });
  addText(slide, `${count}건`, { left: 958, top: y + 11, width: 70, height: 24 }, {
    fontSize: 16,
    color: C.muted,
    alignment: "right",
  });
  addText(slide, `SUD ${sud}`, { left: 1044, top: y + 10, width: 110, height: 26 }, {
    fontSize: 16,
    bold: true,
    color: accent,
    alignment: "right",
  });
}

async function buildDeck() {
  const presentation = Presentation.create({
    slideSize: { width: W, height: H },
  });
  const locationRows = await readCsv(path.join(REPORT_DIR, "tables", "location_summary.csv"));
  const highBurdenRows = (await readCsv(path.join(REPORT_DIR, "tables", "high_burden_context_windows.csv"))).slice(0, 5);
  const locatedDiaries = locationRows.reduce((sum, row) => sum + num(row["일기 수"]), 0);
  const coreLocations = new Set(["집", "학교", "연구실", "성균관대학교"]);
  const coreDiaries = locationRows
    .filter((row) => coreLocations.has(row["위치"]))
    .reduce((sum, row) => sum + num(row["일기 수"]), 0);
  const coreRatio = locatedDiaries ? (coreDiaries / locatedDiaries) * 100 : 0;

  let n = 1;

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    slide.shapes.add({
      geometry: "rect",
      position: { left: 0, top: 0, width: 16, height: H },
      fill: C.teal,
      line: noLine,
    });
    addText(slide, "Mindrium 8주 완료 데이터 분석", {
      left: 74,
      top: 88,
      width: 760,
      height: 112,
    }, { fontSize: 54, bold: true, color: C.ink });
    addText(slide, "결과 변화, 사용량, 걱정 주제, 위치·시간 맥락을 함께 본 발표용 요약", {
      left: 78,
      top: 218,
      width: 760,
      height: 44,
    }, { fontSize: 22, color: C.muted });
    await addChartCard(slide, "14_user_sud_trajectories.png", {
      left: 764,
      top: 76,
      width: 420,
      height: 340,
    }, "사용자별 SUD 변화 궤적");
    addMetric(slide, {
      x: 78, y: 438, w: 258, h: 150,
      value: "40명", label: "8주 완료 사용자", note: "모든 대상자가 최종 8주차까지 완료",
      color: C.teal,
    });
    addMetric(slide, {
      x: 356, y: 438, w: 258, h: 150,
      value: "-3.88점", label: "GAD-7 평균 변화", note: "15.10점에서 11.22점으로 감소",
      color: C.blue,
    });
    addMetric(slide, {
      x: 634, y: 438, w: 258, h: 150,
      value: "90.1%", label: "SUD 악화 없음", note: "수행 전후 SUD 기록 2,214건 기준",
      color: C.green,
    });
    addMetric(slide, {
      x: 912, y: 438, w: 258, h: 150,
      value: `${oneDecimal(coreRatio)}%`, label: "핵심 위치 집중도", note: "집·학교·연구실·성균관대학교 중심",
      color: C.amber,
    });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "핵심 결론은 평균보다 개선자 비율에 있다", "결과는 평균 변화, 의미 있는 개선자, 사용 맥락을 함께 봐야 설득력이 커진다.", "Executive summary");
    addMetric(slide, { x: 82, y: 214, w: 258, h: 156, value: "52.5%", label: "GAD-7 4점 이상 감소", note: "21/40명이 의미 있는 개선 기준을 충족", color: C.teal });
    addMetric(slide, { x: 364, y: 214, w: 258, h: 156, value: "72.5%", label: "GAD-7 3점 이상 감소", note: "29/40명이 최소 개선 기준에 도달", color: C.blue });
    addMetric(slide, { x: 646, y: 214, w: 258, h: 156, value: "22/24명", label: "높은 불안군 이동", note: "8주 후 중등도 이하 구간으로 이동", color: C.coral });
    addMetric(slide, { x: 928, y: 214, w: 258, h: 156, value: "98.1%", label: "8주차 효과 있음", note: "사후 평가 문항에서 긍정 응답 비율", color: C.green });
    addInsightBox(slide, "발표의 중심 메시지", "Mindrium 사용 데이터는 단순 접속 시간보다 일기, 대안적 생각, 행동 계획 같은 능동 과제가 결과 변화와 더 가깝게 연결되는 패턴을 보인다.", {
      left: 116,
      top: 424,
      width: 1048,
      height: 118,
    }, C.teal, C.tealSoft);
    addText(slide, "검증 기준: 사용자 40명 · 차트 14개 · 표 9개 · 검증 오류 0건", {
      left: 116,
      top: 568,
      width: 1048,
      height: 32,
    }, { fontSize: 17, color: C.muted, alignment: "center" });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "GAD-7은 절반 이상에서 의미 있는 감소를 보였다", "평균 감소량은 3.88점이며, 4점 이상 감소자는 21명이다.", "Outcome");
    await addChartCard(slide, "01_gad7_outcome_and_response.png", {
      left: 78,
      top: 190,
      width: 740,
      height: 384,
    }, "GAD-7 평균 변화와 반응자 비율");
    addInsightBox(slide, "결과 해석", "평균 변화만 보면 변화폭이 작아 보일 수 있다. 그러나 4점 이상 감소자가 52.5%, 3점 이상 감소자가 72.5%로 나타나 사용자 단위의 개선 비율이 더 강한 메시지다.", {
      left: 856,
      top: 212,
      width: 316,
      height: 188,
    }, C.blue, C.blueSoft);
    addInsightBox(slide, "발표 포인트", "결과 슬라이드에서는 평균 변화와 함께 반응자 비율을 제시해, 전체 평균 뒤에 있는 사용자 수준의 변화를 함께 보여준다.", {
      left: 856,
      top: 426,
      width: 316,
      height: 134,
    }, C.teal, C.tealSoft);
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "높은 불안군 대부분이 낮은 위험 구간으로 이동했다", "시작 시점 높은 불안군 24명 중 22명이 8주 후 중등도 이하로 이동했다.", "Severity movement");
    await addChartCard(slide, "02_gad7_severity_transition.png", {
      left: 108,
      top: 176,
      width: 574,
      height: 440,
    }, "GAD-7 중증도 전이표");
    addMetric(slide, { x: 728, y: 206, w: 382, h: 142, value: "24명 → 2명", label: "높은 불안군 변화", note: "높음 구간 잔류자는 2명으로 감소", color: C.coral });
    addMetric(slide, { x: 728, y: 376, w: 382, h: 142, value: "30명", label: "8주 후 중등도", note: "최종 시점의 가장 큰 집단", color: C.teal });
    addText(slide, "구간 이동은 평균 점수보다 직관적으로 위험도 완화를 보여준다.", {
      left: 728,
      top: 548,
      width: 382,
      height: 40,
    }, { fontSize: 18, color: C.muted, alignment: "center" });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "PHQ-9은 시작 시점 분포로만 해석한다", "사후 PHQ-9은 수집되지 않았으므로, 기저 특성 설명에 사용한다.", "Baseline profile");
    await addChartCard(slide, "03_phq9_baseline_distribution.png", {
      left: 86,
      top: 188,
      width: 688,
      height: 378,
    }, "PHQ-9 기저 분포");
    addInsightBox(slide, "기저 특성", "시작 시점 PHQ-9 평균은 6.83점이며, 거의 없음 또는 경도 사용자가 31명으로 다수를 차지한다.", {
      left: 818,
      top: 214,
      width: 336,
      height: 146,
    }, C.amber, C.amberSoft);
    addInsightBox(slide, "해석 범위", "이 그래프는 우울 증상의 변화 결과가 아니라, 8주 프로그램 시작 시점의 사용자 구성을 설명하는 지표다.", {
      left: 818,
      top: 386,
      width: 336,
      height: 156,
    }, C.teal, C.tealSoft);
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "SUD는 주차가 진행될수록 낮아졌다", "수행 후 SUD는 3주차 6.03점에서 8주차 4.11점으로 낮아졌다.", "SUD trajectory");
    await addChartCard(slide, "04_weekly_sud_trajectory.png", {
      left: 74,
      top: 188,
      width: 790,
      height: 418,
    }, "주차별 수행 전후 SUD 변화");
    addMetric(slide, { x: 900, y: 214, w: 268, h: 132, value: "1.92점", label: "수행 후 SUD 하락", note: "3주차 6.03 → 8주차 4.11", color: C.teal });
    addMetric(slide, { x: 900, y: 374, w: 268, h: 132, value: "2,214건", label: "SUD 기록 수", note: "2주차 이후 사용 가능한 SUD 기록 기준", color: C.blue });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "대부분의 기록은 수행 직후 악화 없이 끝났다", "전체 SUD 기록 중 수행 후 SUD가 악화되지 않은 비율은 90.1%다.", "Immediate response");
    await addChartCard(slide, "05_sud_delta_and_nonworsening.png", {
      left: 80,
      top: 184,
      width: 764,
      height: 402,
    }, "즉시 SUD 감소와 악화 없음 비율");
    addInsightBox(slide, "안정성 관점", "수행 후 SUD가 높아진 기록은 일부 존재하지만, 전체 기록의 90.1%는 악화 없이 종료됐다.", {
      left: 884,
      top: 220,
      width: 292,
      height: 150,
    }, C.green, C.greenSoft);
    addInsightBox(slide, "해석 주의", "이 결과는 수행 직후 변화에 대한 관찰이며, 장기 효과를 단독으로 증명하는 지표는 아니다.", {
      left: 884,
      top: 398,
      width: 292,
      height: 142,
    }, C.amber, C.amberSoft);
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "5주차 이후 즉시 감소폭이 더 커졌다", "대안적 생각과 행동 계획이 열린 뒤 SUD 감소폭이 0.32점 커졌다.", "Mechanism signal");
    await addChartCard(slide, "08_mechanism_and_week8_evaluation.png", {
      left: 72,
      top: 190,
      width: 812,
      height: 380,
    }, "5주차 전후 SUD 감소폭과 8주차 평가");
    addMetric(slide, { x: 920, y: 216, w: 254, h: 132, value: "+0.32점", label: "즉시 감소폭 차이", note: "3~4주차 0.65 → 5~8주차 0.97", color: C.coral });
    addMetric(slide, { x: 920, y: 378, w: 254, h: 132, value: "75.0%", label: "유지 의도", note: "8주차 평가에서 유지 행동 의도", color: C.teal });
    addText(slide, "인과 단정이 아니라 기능 해금 뒤 나타난 사용 패턴의 변화로 해석한다.", {
      left: 74,
      top: 596,
      width: 1088,
      height: 28,
    }, { fontSize: 17, color: C.muted, alignment: "center" });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "능동 과제가 결과와 더 가깝게 연결됐다", "일기와 대안적 생각 작성량이 높은 그룹에서 SUD 감소가 더 컸다.", "Dose-response");
    await addChartCard(slide, "07_dose_response_active_tasks.png", {
      left: 72,
      top: 184,
      width: 814,
      height: 420,
    }, "사용량과 결과의 관계");
    addInsightBox(slide, "가장 뚜렷한 차이", "일기 작성량 상위 10명은 하위 10명보다 GAD-7 감소량이 1.4점, SUD 감소량이 1.14점 높다.", {
      left: 920,
      top: 208,
      width: 264,
      height: 164,
    }, C.blue, C.blueSoft);
    addInsightBox(slide, "제품 지표 시사점", "단순 체류 시간보다 일기, 대안적 생각, 행동 계획 같은 능동 입력을 핵심 사용 지표로 보는 것이 적절하다.", {
      left: 920,
      top: 402,
      width: 264,
      height: 152,
    }, C.teal, C.tealSoft);
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "사용량은 초반 학습과 후반 반복 실천으로 나뉜다", "초반에는 교육과 적응 부담이 크고, 후반에는 짧은 반복 세션이 중심이 된다.", "Adherence");
    await addChartCard(slide, "06_weekly_adherence_and_screen_time.png", {
      left: 76,
      top: 186,
      width: 766,
      height: 384,
    }, "주차별 수행량과 사용시간");
    addInsightBox(slide, "앱 세션 구조", "전체 앱 세션 중앙값은 10.0분이다. 긴 체류보다 짧고 반복적인 과제 수행에 가까운 사용 패턴이다.", {
      left: 880,
      top: 208,
      width: 300,
      height: 152,
    }, C.teal, C.tealSoft);
    addInsightBox(slide, "운영 포인트", "초반 온보딩과 교육 콘텐츠 분할, 후반 루틴 유지 알림을 분리해서 설계할 필요가 있다.", {
      left: 880,
      top: 390,
      width: 300,
      height: 150,
    }, C.amber, C.amberSoft);
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "야간 사용은 루틴 설계의 근거가 된다", "앱 세션과 일기는 밤·심야 시간대에 많이 나타난다.", "Time pattern");
    await addChartCard(slide, "12_hourly_diary_and_app_sessions.png", {
      left: 74,
      top: 184,
      width: 792,
      height: 410,
    }, "시간대별 일기와 앱 세션");
    addBullet(slide, "상위 시간대는 하루 마무리 후 정리와 이완 목적으로 해석할 수 있다.", 906, 232, 248, C.teal);
    addBullet(slide, "야간 알림은 부담을 높이지 않도록 개인별 사용 시간과 함께 조정해야 한다.", 906, 326, 248, C.coral);
    addBullet(slide, "DAU보다 과제 완료율, 반복률, 시간대별 완료율이 더 적합한 KPI다.", 906, 420, 248, C.blue);
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "걱정 주제는 빈도와 부담을 분리해서 봐야 한다", "많이 기록되는 주제와 SUD가 높은 주제는 같지 않다.", "Worry topics");
    await addChartCard(slide, "09_worry_topic_frequency_burden.png", {
      left: 76,
      top: 184,
      width: 730,
      height: 422,
    }, "걱정 주제별 빈도와 평균 SUD");
    addInsightBox(slide, "빈도 기준", "기본 그룹, 발표와 평가, 외출과 이동이 가장 많이 기록됐다.", {
      left: 846,
      top: 214,
      width: 318,
      height: 132,
    }, C.blue, C.blueSoft);
    addInsightBox(slide, "부담 기준", "미래 계획, 발표와 평가, 건강 염려는 평균 SUD가 상대적으로 높다.", {
      left: 846,
      top: 374,
      width: 318,
      height: 132,
    }, C.coral, C.coralSoft);
    addText(slide, "추천과 콘텐츠 우선순위는 빈도 기준과 부담 기준을 분리해 설계하는 것이 낫다.", {
      left: 846,
      top: 536,
      width: 318,
      height: 44,
    }, { fontSize: 17, color: C.muted, alignment: "center" });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "위치 로그는 통제된 생활 반경과 실제 노이즈를 함께 보여준다", "핵심 위치에 많이 몰리지만, 위치 미입력과 보조 장소도 일부 포함된다.", "Location context");
    await addChartCard(slide, "10_location_count_and_sud.png", {
      left: 70,
      top: 184,
      width: 760,
      height: 406,
    }, "위치별 일기 수와 평균 SUD");
    addMetric(slide, { x: 870, y: 206, w: 284, h: 122, value: "84.2%", label: "위치 연결 일기", note: "2,521/2,994건", color: C.teal });
    addMetric(slide, { x: 870, y: 356, w: 284, h: 122, value: `${oneDecimal(coreRatio)}%`, label: "핵심 위치 집중도", note: "집·학교·연구실·성균관대학교", color: C.amber });
    addMetric(slide, { x: 870, y: 506, w: 284, h: 92, value: "15.8%", label: "위치 미입력", note: "현실적인 누락 패턴 포함", color: C.muted });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "고부담 순간은 특정 위치와 시간대에 모인다", "위치·시간 조합을 보면 개인화 알림과 과제 추천의 후보가 보인다.", "Context windows");
    await addChartCard(slide, "11_location_period_sud_heatmap.png", {
      left: 70,
      top: 182,
      width: 620,
      height: 424,
    }, "위치와 시간대별 평균 SUD 히트맵");
    addText(slide, "상위 고부담 조합", {
      left: 724,
      top: 194,
      width: 448,
      height: 34,
    }, { fontSize: 24, bold: true, color: C.ink });
    highBurdenRows.forEach((row, idx) => {
      addContextRow(
        slide,
        idx + 1,
        row["위치"],
        row["시간대"],
        row["일기 수"],
        row["평균 수행 후 SUD"],
        244 + idx * 62,
      );
    });
    addText(slide, "핵심은 장소 자체보다 “어느 장소에서 어느 시간대에 부담이 커지는가”다.", {
      left: 724,
      top: 566,
      width: 448,
      height: 36,
    }, { fontSize: 17, color: C.muted, alignment: "center" });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "개별 사용자 궤적은 평균 뒤의 차이를 보여준다", "전체 경향은 개선 방향이지만, 개인별 속도와 변동성은 다르게 나타난다.", "Individual trajectories");
    await addChartCard(slide, "14_user_sud_trajectories.png", {
      left: 76,
      top: 184,
      width: 862,
      height: 414,
    }, "사용자별 SUD 궤적");
    addInsightBox(slide, "분석 활용", "평균만 보면 정체, 회복, 큰 변동성을 가진 사용자군이 보이지 않는다.", {
      left: 966,
      top: 212,
      width: 206,
      height: 168,
    }, C.blue, C.blueSoft);
    addInsightBox(slide, "제품 활용", "개인별 궤적은 알림 강도와 재몰입 메시지를 다르게 설계하는 근거가 된다.", {
      left: 966,
      top: 408,
      width: 206,
      height: 168,
    }, C.teal, C.tealSoft);
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "개선 그룹은 더 큰 SUD 감소를 보였다", "4점 이상 개선군은 평균 SUD 감소와 능동 기록량이 함께 높다.", "Response segments");
    await addChartCard(slide, "13_response_segment_usage_patterns.png", {
      left: 74,
      top: 184,
      width: 812,
      height: 398,
    }, "개선 그룹별 사용 패턴");
    addMetric(slide, { x: 924, y: 212, w: 248, h: 116, value: "21명", label: "4점 이상 개선", note: "평균 SUD 감소 2.55점", color: C.teal });
    addMetric(slide, { x: 924, y: 356, w: 248, h: 116, value: "46.0건", label: "대안적 생각", note: "4점 이상 개선군 평균", color: C.blue });
    addMetric(slide, { x: 924, y: 500, w: 248, h: 92, value: "77.7건", label: "일기 작성", note: "4점 이상 개선군 평균", color: C.coral });
    addFooter(slide, n++);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = C.bg;
    addTitle(slide, "분석 결과는 맞춤 개입 설계로 연결된다", "다음 단계는 결과 지표, 사용 지표, 위치·시간 맥락을 하나의 의사결정 체계로 묶는 것이다.", "Implications");
    addInsightBox(slide, "1. 결과 판단", "GAD-7 평균 변화보다 3점·4점 이상 개선자 비율과 중증도 이동을 전면에 둔다.", {
      left: 88,
      top: 204,
      width: 510,
      height: 136,
    }, C.blue, C.blueSoft);
    addInsightBox(slide, "2. 핵심 사용 지표", "체류 시간보다 일기, 대안적 생각, 행동 계획, 주차별 반복률을 주요 지표로 본다.", {
      left: 682,
      top: 204,
      width: 510,
      height: 136,
    }, C.teal, C.tealSoft);
    addInsightBox(slide, "3. 맞춤 추천", "빈도가 높은 걱정과 SUD가 높은 걱정을 분리해 콘텐츠와 과제를 추천한다.", {
      left: 88,
      top: 388,
      width: 510,
      height: 136,
    }, C.coral, C.coralSoft);
    addInsightBox(slide, "4. 맥락 기반 운영", "위치·시간별 고부담 순간을 활용해 알림 시간과 재몰입 메시지를 조정한다.", {
      left: 682,
      top: 388,
      width: 510,
      height: 136,
    }, C.amber, C.amberSoft);
    addText(slide, "검증된 데이터 구조를 유지한 상태에서, 발표용 분석과 제품 개선 가설을 동시에 제시할 수 있다.", {
      left: 118,
      top: 584,
      width: 1044,
      height: 34,
    }, { fontSize: 19, bold: true, color: C.ink, alignment: "center" });
    addFooter(slide, n++);
  }

  await fs.mkdir(PREVIEW_DIR, { recursive: true });
  await fs.mkdir(QA_DIR, { recursive: true });

  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await presentation.export({ slide, format: "png", scale: 1 });
    await writeBlob(path.join(PREVIEW_DIR, `${stem}.png`), png);
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(QA_DIR, `${stem}.layout.json`), await layout.text());
  }

  const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
  await writeBlob(path.join(QA_DIR, "mindrium_final_presentation_montage.webp"), montage);

  const snapshot = await presentation.inspect({
    kind: "slide,textbox,shape,image,table,chart,layout",
    maxChars: 60000,
  });
  await fs.writeFile(path.join(QA_DIR, "inspect.ndjson"), snapshot.ndjson);

  const pptx = await PresentationFile.exportPptx(presentation);
  await fs.mkdir(path.dirname(FINAL_PPTX), { recursive: true });
  await pptx.save(FINAL_PPTX);

  console.log(`PPTX=${FINAL_PPTX}`);
  console.log(`PREVIEW_DIR=${PREVIEW_DIR}`);
  console.log(`QA_DIR=${QA_DIR}`);
  console.log(`SLIDES=${presentation.slides.items.length}`);
}

buildDeck().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
