import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFile as execFileCallback } from "node:child_process";
import { promisify } from "node:util";
import { FileBlob, PresentationFile } from "@oai/artifact-tool";

const execFile = promisify(execFileCallback);

const STARTER_PPTX =
  process.env.STARTER_PPTX ??
  "/private/tmp/codex-presentations/manual-kocca-stage-template/tmp/template-starter.pptx";
const REPORT_DIR =
  "/Users/ubdbd/Desktop/연구실/범불안장애 DTx/Lab_test/analytics_report/final_comprehensive";
const CHART_DIR = path.join(REPORT_DIR, "charts");
const FINAL_PPTX =
  process.env.FINAL_PPTX ??
  path.resolve("outputs/Mindrium_2026_콘진원_단계보고서_발표자료.pptx");
const PREVIEW_DIR =
  process.env.PREVIEW_DIR ?? path.resolve("outputs/kocca_stage_report_preview");
const QA_DIR = process.env.QA_DIR ?? path.resolve("outputs/kocca_stage_report_qa");

async function writeBlob(filePath, blob) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, new Uint8Array(await blob.arrayBuffer()));
}

async function chartBytes(name) {
  return await fs.readFile(path.join(CHART_DIR, name));
}

const TEMPLATE_TEXT_TO_CLEAR = [
  "플랫폼 지식그래프 ",
  "플랫폼 지식그래프",
  "지식그래프 구축(Knowledge Graph Construction)",
  "지식그래프 구축",
  "신뢰가능한 의료 상담을 위한 지식그래프 구축 프레임워크 개발",
  "기존 의료상담 에이전트는 내과, 종양학, 간질환 중심의 검증된 지식그래프(KG)를 활용하여 의료 상담을 제공합니다. 그러나 정신의학(충동/중독/불안장애 등) 지식이 부족하여 관련 질의에 대한 신뢰성 있는 답변에 한계가 있습니다. 이에 정신의학 지식그래프를 구축·확장하여 의료 상담 범위를 확대하고자 합니다. ",
  "기존 방법 대비 가장 높은 KG 구축 성능(F1) 달성 ",
  "구축 성능은 유지하면서 더 작은 KG 생성 ",
  "RAG 기반 질의응답 성능 최고(83.17%) ",
  "기존 방법보다 적은 비용과 시간으로 KG 구축 ",
  "• F1 Score: 91.21%(Ours) > 89.16% > 86.68% > 74.65% > 42.37%\n• 신뢰성 높은 의료 지식그래프 구축 가능 \n• 정신의학 지식 추가 시에도 정확한 지식 구축 기반 제공 ",
  "• 정신의학 개념이 추가되어도 중복 없이 효율적인 그래프 \n관리 가능\n• 상담 시스템의 검색 및 추론 효율 향상  ",
  "• Retrieval-Augmented Generation (RAG) 기반 질의응답 성능 향상 \n• 지식그래프 품질이 의료 상담 성능 향상으로 직접 연결됨\n• 정신의학 지식 확장을 통해 상담 가능한 질의 범위 확대 기대 ",
  "• 정신의학 지식을 추가 구축할 때도 효율적으로 확장 가능\n• 대규모 의료 지식그래프 유지·관리 비용 절감 ",
  "01. 정신의학 의료상담 서비스 고도화 ",
  "정신건강 관련 질의에 대한 신뢰성 있는 의료 상담 제공 ",
  "02. 의료 지식그래프 확장 ",
  "정신의학 지식을 추가하여 의료 상담 범위 확대 ",
  "03. 타 의료 분야로 확장 가능  ",
  "내과, 외과, 소아과 등 다양한 전문 분야로 지식그래프 확장 가능 ",
  "04. 타 도메인 적용 가능 ",
  "법률, 교육, 금융 등 전문 분야의 지식그래프 구축에도 활용 가능 ",
  "연구 2",
  "연구 3",
  "연구 4",
  "연구 5",
  "연구 설명",
  "연구개발과제의 주요 수행 카테고리",
  "결과 내용",
  "결과 1",
  "결과 2",
  "결과 3",
  "결과 4",
  "01. ~~왼쪽에 이모지 알맞은 거 화이트 색상 넣어주세요",
  "02. ~~",
  "03. ~~",
  "04. ~~",
  "설명",
  "‹#›",
];

async function sanitizePptxText(pptxPath) {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "kocca-pptx-sanitize-"));
  const rebuilt = `${tmpDir}.pptx`;
  try {
    await execFile("unzip", ["-q", pptxPath, "-d", tmpDir]);
    const slideDir = path.join(tmpDir, "ppt", "slides");
    const entries = await fs.readdir(slideDir);
    for (const entry of entries) {
      if (!entry.endsWith(".xml")) continue;
      const xmlPath = path.join(slideDir, entry);
      let xml = await fs.readFile(xmlPath, "utf8");
      for (const term of TEMPLATE_TEXT_TO_CLEAR) {
        xml = xml.replaceAll(term, "");
        xml = xml.replaceAll(term.replaceAll(">", "&gt;").replaceAll("<", "&lt;"), "");
      }
      await fs.writeFile(xmlPath, xml, "utf8");
    }
    await execFile("zip", ["-qr", rebuilt, "."], { cwd: tmpDir });
    await fs.copyFile(rebuilt, pptxPath);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
    await fs.rm(rebuilt, { force: true });
  }
}

function textString(shape) {
  try {
    return String(shape.text?.plainText ?? shape.text?.text ?? "").trim();
  } catch {
    return "";
  }
}

function textShapes(slide) {
  return slide.shapes.items.filter((shape) => textString(shape).length > 0);
}

function setTexts(slide, values) {
  const shapes = textShapes(slide);
  values.forEach((value, idx) => {
    if (idx < shapes.length && value !== undefined && value !== null) {
      shapes[idx].text = value;
    }
  });
}

function replacePageNumber(slide, number) {
  for (const shape of slide.shapes.items) {
    if (textString(shape) === "‹#›") {
      shape.text = String(number).padStart(2, "0");
    }
  }
}

function addText(slide, text, position, options = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position,
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontSize: options.fontSize ?? 18,
    bold: options.bold ?? false,
    color: options.color ?? "#24323A",
    alignment: options.alignment ?? "left",
  };
  return shape;
}

function addBox(slide, position, options = {}) {
  const shape = slide.shapes.add({
    geometry: options.geometry ?? "rect",
    position,
    fill: options.fill ?? "white",
    line: options.line ?? { style: "solid", fill: "none", width: 0 },
    borderRadius: options.borderRadius,
    shadow: options.shadow,
  });
  return shape;
}

function addStyledText(slide, text, position, options = {}) {
  const shape = addText(slide, text, position, options);
  shape.text.style = {
    fontSize: options.fontSize ?? 18,
    bold: options.bold ?? false,
    color: options.color ?? "#24323A",
    alignment: options.alignment ?? "left",
  };
  return shape;
}

async function addChart(slide, imageName, position, alt) {
  slide.images.add({
    blob: await chartBytes(imageName),
    contentType: "image/png",
    alt,
    fit: "contain",
    position,
    geometry: "roundRect",
    borderRadius: 8,
  });
}

async function replaceFirstLargeImage(slide, imageName, position, alt) {
  const image = slide.images.items[0];
  if (!image) {
    await addChart(slide, imageName, position, alt);
    return;
  }
  image.replace({
    blob: await chartBytes(imageName),
    contentType: "image/png",
    alt,
    fit: "contain",
  });
  image.position = position;
  image.fit = "contain";
  image.geometry = "roundRect";
  image.borderRadius = 8;
}

function section(slide, num, title, subtitle, english) {
  setTexts(slide, ["SECTION", num, title, subtitle, english]);
  addBox(slide, { left: 500, top: 205, width: 720, height: 300 }, { fill: "white" });
  addStyledText(slide, title, { left: 528, top: 224, width: 720, height: 100 }, {
    fontSize: 58,
    color: "#333333",
  });
  addBox(slide, { left: 533, top: 350, width: 6, height: 42 }, { fill: "#0E6A43" });
  addStyledText(slide, english, { left: 556, top: 350, width: 460, height: 42 }, {
    fontSize: 25,
    color: "#667680",
  });
  addStyledText(slide, subtitle, { left: 528, top: 425, width: 620, height: 54 }, {
    fontSize: 16,
    color: "#667680",
  });
}

function fourCards(slide, title, eyebrow, cards) {
  setTexts(slide, [
    title,
    eyebrow,
    cards[0].title,
    cards[1].title,
    cards[2].title,
    cards[3].title,
    cards[0].body,
    cards[1].body,
    cards[2].body,
    cards[3].body,
  ]);

  addBox(slide, { left: 55, top: 36, width: 820, height: 102 }, { fill: "white" });
  addStyledText(slide, title, { left: 64, top: 48, width: 590, height: 58 }, {
    fontSize: 36,
    color: "#222222",
  });
  addStyledText(slide, eyebrow, { left: 68, top: 105, width: 590, height: 32 }, {
    fontSize: 18,
    color: "#667680",
  });

  addBox(slide, { left: 56, top: 160, width: 1168, height: 514 }, { fill: "white" });
  const positions = [
    { left: 64, top: 176, width: 564, height: 213, dark: true },
    { left: 652, top: 176, width: 564, height: 213, dark: false },
    { left: 64, top: 413, width: 564, height: 213, dark: false },
    { left: 652, top: 413, width: 564, height: 213, dark: true },
  ];

  positions.forEach((pos, idx) => {
    const card = cards[idx];
    addBox(slide, pos, {
      geometry: "roundRect",
      fill: "white",
      line: { style: "solid", fill: "#DDE8E3", width: 1 },
      borderRadius: 6,
    });
    addBox(slide, { left: pos.left, top: pos.top, width: pos.width, height: 73 }, {
      fill: pos.dark ? "#0E6A43" : "#EAF7EF",
      line: { style: "solid", fill: "none", width: 0 },
    });
    addStyledText(
      slide,
      card.title,
      { left: pos.left + 22, top: pos.top + 18, width: pos.width - 44, height: 38 },
      {
        fontSize: card.title.length > 18 ? 21 : 24,
        bold: false,
        color: pos.dark ? "#FFFFFF" : "#0E6A43",
        alignment: "center",
      },
    );
    addStyledText(
      slide,
      card.body,
      { left: pos.left + 24, top: pos.top + 91, width: pos.width - 48, height: 104 },
      {
        fontSize: 16,
        color: "#4B5A66",
      },
    );
  });
}

function fourImplications(slide, title, items) {
  setTexts(slide, [
    title,
    items[0].title,
    "",
    items[1].title,
    items[2].title,
    items[3].title,
    items[3].body,
    items[2].body,
    items[1].body,
    items[0].body,
  ]);

  addBox(slide, { left: 56, top: 48, width: 610, height: 78 }, { fill: "white" });
  addStyledText(slide, title, { left: 64, top: 61, width: 610, height: 58 }, {
    fontSize: 34,
    color: "#222222",
  });

  addBox(slide, { left: 55, top: 132, width: 1170, height: 536 }, { fill: "white" });
  const rows = [142, 278, 414, 556];
  rows.forEach((top, idx) => {
    const item = items[idx];
    addBox(slide, { left: 64, top, width: 1152, height: 91 }, {
      geometry: "roundRect",
      fill: "white",
      line: { style: "solid", fill: "#DDE8E3", width: 1 },
      borderRadius: 8,
    });
    addBox(slide, { left: 64, top, width: 6, height: 89 }, { fill: "#0E6A43" });
    addBox(slide, { left: 93, top: top + 22, width: 48, height: 48 }, {
      geometry: "ellipse",
      fill: "#0E6A43",
      line: { style: "solid", fill: "none", width: 0 },
    });
    addStyledText(slide, String(idx + 1).padStart(2, "0"), { left: 98, top: top + 34, width: 38, height: 22 }, {
      fontSize: 15,
      bold: true,
      color: "#FFFFFF",
      alignment: "center",
    });
    addStyledText(slide, item.title, { left: 169, top: top + 17, width: 820, height: 31 }, {
      fontSize: 19,
      color: "#24323A",
    });
    addStyledText(slide, item.body, { left: 169, top: top + 52, width: 830, height: 28 }, {
      fontSize: 15,
      color: "#44515C",
    });
  });
}

function chartHeader(slide, title, caption) {
  addBox(slide, { left: 56, top: 34, width: 930, height: 80 }, { fill: "white" });
  addStyledText(slide, title, { left: 64, top: 47, width: 900, height: 62 }, {
    fontSize: title.length > 22 ? 32 : 36,
    color: "#222222",
  });
  addBox(slide, { left: 64, top: 118, width: 1152, height: 78 }, { fill: "#F7F9F8" });
  addBox(slide, { left: 64, top: 118, width: 6, height: 78 }, { fill: "#0E6A43" });
  addStyledText(slide, caption, { left: 104, top: 129, width: 1080, height: 56 }, {
    fontSize: caption.length > 70 ? 14 : 16,
    color: "#24323A",
  });
}

function drawToc(slide) {
  addBox(slide, { left: 72, top: 58, width: 260, height: 58 }, { fill: "white" });
  addStyledText(slide, "목차", { left: 82, top: 64, width: 230, height: 48 }, {
    fontSize: 39,
    color: "#222222",
  });
  addBox(slide, { left: 116, top: 190, width: 510, height: 440 }, { fill: "white" });
  const items = [
    ["01", "분석 개요"],
    ["02", "주요 결과"],
    ["03", "사용량 및 작동 패턴"],
    ["04", "위치·시간 맥락"],
    ["05", "활용 계획"],
  ];
  items.forEach(([num, label], idx) => {
    const top = 202 + idx * 94;
    addStyledText(slide, num, { left: 118, top, width: 54, height: 36 }, {
      fontSize: 31,
      color: "#0E6A43",
    });
    addStyledText(slide, label, { left: 190, top: top + 3, width: 430, height: 34 }, {
      fontSize: 22,
      color: "#24323A",
    });
  });
}

function drawPageNumber(slide, number) {
  addBox(slide, { left: 1128, top: 672, width: 80, height: 28 }, { fill: "white" });
  addStyledText(slide, String(number).padStart(2, "0"), { left: 1148, top: 676, width: 40, height: 18 }, {
    fontSize: 11,
    color: "#70777C",
    alignment: "right",
  });
}

async function main() {
  await fs.mkdir(PREVIEW_DIR, { recursive: true });
  await fs.mkdir(QA_DIR, { recursive: true });

  const presentation = await PresentationFile.importPptx(await FileBlob.load(STARTER_PPTX));
  const s = presentation.slides.items;

  setTexts(s[0], [
    "SUNGKYUNKWAN UNIVERSITY",
    "[한국콘텐츠진흥원] 문화체육관광 연구개발사업 2026년 단계보고서 발표",
    "Mindrium 8주 완료 데이터 분석 및",
    "서비스 활용 인사이트",
    "연구책임자",
    "성균관대학교 오하영 교수",
    "2026.07.02",
    "한국콘텐츠진흥원 역삼분원",
    "Eight-week completed-use data analysis and service insight report",
  ]);

  setTexts(s[1], [
    "01",
    "분석 개요",
    "02",
    "주요 결과",
    "03",
    "사용량 및 작동 패턴",
    "04",
    "위치·시간 맥락",
    "05",
    "활용 계획",
    "SUNGKYUNKWAN UNIV.",
    "목차",
    "02",
  ]);
  drawToc(s[1]);

  section(s[2], "01", "분석 개요", "8주 완료 데이터의 구조와 검증 결과", "Dataset Overview");
  setTexts(s[3], [
    "최종 분석 데이터 구성 및 검증",
    "8주 완료 사용자 40명의 사용 기록을 기준으로 사용자, 일기, 이완, 교육 세션, 위치·시간 맥락을 통합 분석했다. 최종 데이터는 위치 라벨 참조, SUD 범위, 주차별 완료 조건, 차트·표 생성 여부를 자동 검증했으며 검증 오류는 0건이다.",
  ]);
  await replaceFirstLargeImage(
    s[3],
    "06_weekly_adherence_and_screen_time.png",
    { left: 194, top: 222, width: 900, height: 430 },
    "주차별 과제 수행량과 앱 사용 시간",
  );
  chartHeader(
    s[3],
    "최종 분석 데이터 구성 및 검증",
    "8주 완료 사용자 40명의 사용 기록을 기준으로 사용자, 일기, 이완, 교육 세션, 위치·시간 맥락을 통합 분석했다. 자동 검증 결과 오류는 0건이다.",
  );

  fourCards(s[4], "연구 결과", "8주 완료 데이터의 분석 가능성", [
    {
      title: "8주 완료 사용자 40명",
      body: "• 모든 사용자는 최종 8주차까지 완료\n• last_completed_week=8 기준 충족\n• 주차별 treatment_progress 검증 완료",
    },
    {
      title: "일기 2,994건 축적",
      body: "• 오늘 과제 일기와 SUD 기록 포함\n• 2주차 이후 SUD 기록 2,214건\n• 주차별 최소 작성 기준 충족",
    },
    {
      title: "분석 차트 14개 생성",
      body: "• GAD-7, PHQ-9, SUD, 사용량 분석\n• 걱정 주제, 위치·시간, 사용자군 분석\n• 발표용 표 9개 함께 생성",
    },
    {
      title: "검증 오류 0건",
      body: "• 위치 라벨과 일기 참조 정합성 확인\n• 날짜 역전과 SUD 범위 이상 없음\n• Mongo import 가능한 JSON 구조 유지",
    },
  ]);

  fourImplications(s[5], "기대 효과 및 활용 분야", [
    {
      title: "01. 결과 중심 보고 체계",
      body: "평균 변화뿐 아니라 개선자 비율과 중증도 이동을 함께 제시",
    },
    {
      title: "02. 사용량 기반 지표 설계",
      body: "일기, 대안적 생각, 이완 수행량을 주요 사용 지표로 활용",
    },
    {
      title: "03. 맥락 기반 개인화",
      body: "위치·시간별 부담 순간을 활용해 알림과 추천 전략 설계",
    },
    {
      title: "04. 데이터 검증 자동화",
      body: "JSON 구조와 분석 산출물 검증을 반복 실행 가능한 방식으로 유지",
    },
  ]);

  section(s[6], "02", "주요 결과", "평균보다 개선자 비율과 위험도 이동을 중심으로 해석", "Outcome Analysis");
  setTexts(s[7], ["GAD-7 결과 변화와 개선자 비율"]);
  addText(s[7], "평균 감소량은 3.88점이며, 4점 이상 개선자는 21명이다.", { left: 104, top: 124, width: 980, height: 36 }, { fontSize: 17, color: "#667680" });
  await addChart(s[7], "01_gad7_outcome_and_response.png", { left: 116, top: 204, width: 1048, height: 410 }, "GAD-7 평균 변화와 개선자 비율");
  chartHeader(s[7], "GAD-7 결과 변화와 개선자 비율", "평균 감소량은 3.88점이며, 4점 이상 개선자는 21명이다.");

  fourCards(s[8], "연구 결과", "GAD-7 결과 요약", [
    {
      title: "평균 3.88점 감소",
      body: "• 시작 평균 15.10점\n• 8주 후 평균 11.22점\n• 평균 변화와 사용자별 반응을 함께 해석",
    },
    {
      title: "4점 이상 개선 52.5%",
      body: "• 21/40명이 의미 있는 개선 기준 충족\n• 평균보다 개선자 비율이 더 직관적인 결과 지표",
    },
    {
      title: "3점 이상 개선 72.5%",
      body: "• 29/40명이 최소 개선 기준에 도달\n• 개선 경험 사용자가 다수로 확인됨",
    },
    {
      title: "높은 불안군 22/24명 이동",
      body: "• 시작 시점 높은 불안군 대부분이 중등도 이하로 이동\n• 위험 구간 완화 메시지가 명확함",
    },
  ]);

  fourImplications(s[9], "기대 효과 및 활용 분야", [
    {
      title: "01. 반응자 중심 결과 제시",
      body: "평균 변화보다 개선 기준을 충족한 사용자 비율을 먼저 제시",
    },
    {
      title: "02. 위험도 이동 시각화",
      body: "중증도 전이표로 낮은 위험 구간 이동을 직관적으로 설명",
    },
    {
      title: "03. PHQ-9은 기저 특성으로 활용",
      body: "사후 PHQ-9이 없으므로 시작 시점 사용자 구성을 설명",
    },
    {
      title: "04. 결과 해석 범위 명확화",
      body: "관찰 데이터 기반 변화 패턴으로 표현하고 인과 단정은 피함",
    },
  ]);

  section(s[10], "03", "사용량 및 작동 패턴", "SUD 변화와 능동 과제 수행의 관계", "Engagement Pattern");
  setTexts(s[11], ["주차별 SUD 변화"]);
  addText(s[11], "수행 후 SUD는 3주차 6.03점에서 8주차 4.11점으로 낮아졌다.", { left: 104, top: 124, width: 980, height: 36 }, { fontSize: 17, color: "#667680" });
  await addChart(s[11], "04_weekly_sud_trajectory.png", { left: 128, top: 204, width: 1020, height: 410 }, "주차별 수행 전후 SUD 변화");
  chartHeader(s[11], "주차별 SUD 변화", "수행 후 SUD는 3주차 6.03점에서 8주차 4.11점으로 낮아졌다.");

  fourCards(s[12], "연구 결과", "SUD 및 작동 패턴 요약", [
    {
      title: "SUD 기록 2,214건",
      body: "• 2주차 이후 사용 가능한 기록 기준\n• 수행 전·후 점수를 함께 저장\n• 주차별 변화 추적 가능",
    },
    {
      title: "악화 없음 비율 90.1%",
      body: "• 대부분의 기록이 수행 직후 악화 없이 종료\n• 즉시 반응 안정성을 보는 보조 지표",
    },
    {
      title: "5주차 이후 감소폭 +0.32점",
      body: "• 3~4주차 평균 감소 0.65점\n• 5~8주차 평균 감소 0.97점\n• 대안적 생각 기능 이후 변화 확대",
    },
    {
      title: "8주차 효과 있음 98.1%",
      body: "• 사후 평가 문항에서 긍정 응답 다수\n• 유지 의도는 75.0%로 확인",
    },
  ]);

  fourImplications(s[13], "기대 효과 및 활용 분야", [
    {
      title: "01. 능동 과제 중심 KPI",
      body: "단순 접속보다 일기와 대안적 생각 수행량을 핵심 사용 지표로 설정",
    },
    {
      title: "02. 기능 해금 전후 비교",
      body: "5주차 이후 SUD 감소폭 변화를 작동 기전 가설로 활용",
    },
    {
      title: "03. 즉시 반응 모니터링",
      body: "수행 후 악화 기록을 안전성·부담 지표로 지속 추적",
    },
    {
      title: "04. 사용자군별 개입 조정",
      body: "정체·회복·변동성 사용자군을 분리해 재몰입 전략 설계",
    },
  ]);

  section(s[14], "04", "위치·시간 맥락", "생활 반경 안에서 부담이 커지는 순간 식별", "Context Insight");
  setTexts(s[15], ["위치별 기록량과 평균 SUD"]);
  addText(s[15], "핵심 위치 집중도는 89.7%이며, 위치가 연결된 일기는 2,521건이다.", { left: 104, top: 124, width: 980, height: 36 }, { fontSize: 17, color: "#667680" });
  await addChart(s[15], "10_location_count_and_sud.png", { left: 116, top: 204, width: 1048, height: 410 }, "위치별 기록량과 평균 SUD");
  chartHeader(s[15], "위치별 기록량과 평균 SUD", "핵심 위치 집중도는 89.7%이며, 위치가 연결된 일기는 2,521건이다.");

  fourCards(s[16], "연구 결과", "위치·시간 맥락 요약", [
    {
      title: "위치 연결 일기 84.2%",
      body: "• 2,521/2,994건에 위치·시간 정보 연결\n• 위치 없는 기록도 15.8% 유지\n• 실제 사용 누락 패턴 반영",
    },
    {
      title: "핵심 위치 집중도 89.7%",
      body: "• 집, 학교, 연구실, 성균관대학교 중심\n• Lab test의 통제된 생활 반경을 반영",
    },
    {
      title: "위치 자동 입력 26.3%",
      body: "• 직접 입력과 자동 입력이 혼합됨\n• 사용자 부담을 낮추는 보조 입력 방식",
    },
    {
      title: "고부담 조합 식별",
      body: "• 연구실·심야, 집·심야, 학교·오후가 상위 조합\n• 장소와 시간대를 함께 봐야 함",
    },
  ]);

  fourImplications(s[17], "기대 효과 및 활용 분야", [
    {
      title: "01. 맥락 기반 알림",
      body: "사용자가 실제로 기록하는 시간대에 맞춰 알림 강도와 시간을 조정",
    },
    {
      title: "02. 장소별 과제 추천",
      body: "집, 학교, 연구실 등 반복 장소별로 다른 과제와 문구 제공",
    },
    {
      title: "03. 부담 기준 우선순위",
      body: "자주 기록되는 장소와 평균 SUD가 높은 장소를 분리해서 해석",
    },
    {
      title: "04. 생활 노이즈 보존",
      body: "위치 미입력과 시간 흔들림을 유지해 과하게 정제된 로그를 피함",
    },
  ]);

  section(s[18], "05", "활용 계획", "분석 결과를 서비스 지표와 개인화 설계로 연결", "Application Plan");
  setTexts(s[19], ["사용량과 결과의 관계"]);
  addText(s[19], "일기와 대안적 생각 같은 능동 과제가 결과 변화와 더 가깝게 연결된다.", { left: 104, top: 124, width: 980, height: 36 }, { fontSize: 17, color: "#667680" });
  await addChart(s[19], "07_dose_response_active_tasks.png", { left: 118, top: 204, width: 1044, height: 410 }, "능동 과제 사용량과 결과의 관계");
  chartHeader(s[19], "사용량과 결과의 관계", "일기와 대안적 생각 같은 능동 과제가 결과 변화와 더 가깝게 연결된다.");

  fourImplications(s[20], "기대 효과 및 활용 분야", [
    {
      title: "01. 보고 지표 고도화",
      body: "GAD-7 평균 변화, 개선자 비율, 중증도 이동을 함께 제시",
    },
    {
      title: "02. 서비스 KPI 재정의",
      body: "DAU와 체류시간보다 과제 완료율과 반복률 중심으로 관리",
    },
    {
      title: "03. 개인화 추천 설계",
      body: "걱정 주제, 위치, 시간대, SUD 변화를 조합해 추천 기준 도출",
    },
    {
      title: "04. 재몰입 전략",
      body: "정체 사용자와 변동성 큰 사용자에게 다른 알림·과제 경로 제공",
    },
  ]);

  fourCards(s[21], "연구 결과", "발표 핵심 메시지", [
    {
      title: "결과는 사용자 단위로 설명",
      body: "• GAD-7 4점 이상 개선 52.5%\n• 3점 이상 개선 72.5%\n• 평균 변화보다 설득력 있는 메시지",
    },
    {
      title: "능동 과제가 핵심 사용 지표",
      body: "• 일기 작성량 상위군의 결과 변화가 큼\n• 대안적 생각 수와 SUD 감소가 함께 증가\n• 단순 접속보다 수행 중심으로 해석",
    },
    {
      title: "맥락 데이터는 개인화 근거",
      body: "• 핵심 위치 집중도 89.7%\n• 고부담 위치·시간 조합 식별\n• 알림과 과제 추천 최적화 가능",
    },
    {
      title: "분석 산출물은 재사용 가능",
      body: "• Mongo import 가능한 JSON 유지\n• 차트 14개와 표 9개 생성\n• 검증 오류 0건 기준으로 관리",
    },
  ]);

  for (let i = 0; i < s.length; i += 1) {
    replacePageNumber(s[i], i + 1);
    if (i > 0) {
      drawPageNumber(s[i], i + 1);
    }
  }

  for (const [index, slide] of s.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await presentation.export({ slide, format: "png", scale: 1 });
    await writeBlob(path.join(PREVIEW_DIR, `${stem}.png`), png);
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(QA_DIR, `${stem}.layout.json`), await layout.text());
  }
  const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
  await writeBlob(path.join(QA_DIR, "kocca_stage_report_montage.webp"), montage);
  const inspect = await presentation.inspect({ kind: "slide,textbox,shape,image,table,chart,layout", maxChars: 80000 });
  await fs.writeFile(path.join(QA_DIR, "inspect.ndjson"), inspect.ndjson, "utf8");

  await fs.mkdir(path.dirname(FINAL_PPTX), { recursive: true });
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(FINAL_PPTX);
  await sanitizePptxText(FINAL_PPTX);

  const sanitizedPresentation = await PresentationFile.importPptx(await FileBlob.load(FINAL_PPTX));
  for (const [index, slide] of sanitizedPresentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await sanitizedPresentation.export({ slide, format: "png", scale: 1 });
    await writeBlob(path.join(PREVIEW_DIR, `${stem}.png`), png);
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(QA_DIR, `${stem}.layout.json`), await layout.text());
  }
  const sanitizedMontage = await sanitizedPresentation.export({ format: "webp", montage: true, scale: 1 });
  await writeBlob(path.join(QA_DIR, "kocca_stage_report_montage.webp"), sanitizedMontage);
  const sanitizedInspect = await sanitizedPresentation.inspect({ kind: "slide,textbox,shape,image,table,chart,layout", maxChars: 80000 });
  await fs.writeFile(path.join(QA_DIR, "inspect.ndjson"), sanitizedInspect.ndjson, "utf8");
  await fs.writeFile(`${FINAL_PPTX}.inspect.ndjson`, sanitizedInspect.ndjson, "utf8");

  console.log(`PPTX=${FINAL_PPTX}`);
  console.log(`PREVIEW_DIR=${PREVIEW_DIR}`);
  console.log(`QA_DIR=${QA_DIR}`);
  console.log(`SLIDES=${s.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
