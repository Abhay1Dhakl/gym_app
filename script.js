const brand = {
  brandName: "Abhay Method",
  shortName: "AM",
  coachName: "Abhay",
  descriptor: "private strength and physique coaching",
};

const landingMetrics = [
  { value: "31", label: "active clients" },
  { value: "89%", label: "weekly adherence" },
  { value: "11h", label: "admin saved / week" },
  { value: "4.9", label: "avg check-in score" },
];

const systemCards = [
  {
    tag: "Coach HQ",
    title: "One command center for your roster",
    text:
      "Open the day with client priorities, check-ins, payment issues, session notes, and week-by-week program work in one place.",
  },
  {
    tag: "Client App",
    title: "A branded experience clients actually remember",
    text:
      "Training plans, nutrition targets, habit tracking, progress photos, and direct communication all feel like they come from you, not a generic platform.",
  },
  {
    tag: "Business Ops",
    title: "Operations that stop leaking through spreadsheets",
    text:
      "Track invoices, automate follow-ups, segment clients by risk, and keep your coaching business from living across six disconnected tools.",
  },
];

const features = [
  {
    tag: "Programs",
    title: "Spreadsheet-fast builder",
    text:
      "Create training blocks, assign exercise prescriptions, add progression rules, and ship polished plans without living in Sheets.",
  },
  {
    tag: "Clients",
    title: "Centralized client records",
    text:
      "Keep goals, injuries, compliance notes, progress markers, and communication history in one durable profile.",
  },
  {
    tag: "Nutrition",
    title: "Macros, meals, and adherence",
    text:
      "Set targets, organize meal structures, track check-in quality, and spot nutrition drift before results stall.",
  },
  {
    tag: "Comms",
    title: "Messaging with coaching context",
    text:
      "Keep conversations tied to client profiles, progress uploads, session notes, and check-in decisions.",
  },
  {
    tag: "Billing",
    title: "Payments and retention visibility",
    text:
      "See overdue invoices, recurring payments, revenue concentration, and clients at risk of churning.",
  },
  {
    tag: "Brand",
    title: "Looks like your business",
    text:
      "This starter is intentionally personal-first: one coach, one aesthetic system, one memorable experience.",
  },
];

const dashboardKPIs = [
  { label: "Monthly recurring revenue", value: "$12,480", note: "Up 8.4% vs last month" },
  { label: "Clients retained", value: "93%", note: "3 at-risk accounts flagged" },
  { label: "Check-ins completed", value: "24 / 31", note: "7 due before Friday" },
  { label: "Programs updated", value: "18", note: "Week 5 block pushed live" },
];

const priorityItems = [
  "Review Maya's form video before 10:00.",
  "Send travel workout to Rohan.",
  "Chase one overdue invoice from S. Thapa.",
  "Adjust week 5 loads for the advanced strength group.",
];

const actionItems = [
  "Create a new intake workflow",
  "Assign a 4-day hypertrophy block",
  "Send a nutrition adherence reminder",
  "Export this month's revenue summary",
];

const dashboardModules = [
  {
    id: "overview",
    label: "Overview",
    description: "Daily pulse across clients, programming, and business performance.",
    render: () => `
      <div class="module-grid overview-grid">
        <article class="surface-card">
          <p class="card-label">Business Snapshot</p>
          <h3>Everything that needs your attention today</h3>
          <div class="panel-subgrid three-up">
            <div class="metric-chip">
              <strong>7</strong>
              <span>check-ins pending review</span>
            </div>
            <div class="metric-chip">
              <strong>3</strong>
              <span>clients with low recovery scores</span>
            </div>
            <div class="metric-chip">
              <strong>1</strong>
              <span>invoice overdue more than 3 days</span>
            </div>
          </div>
          <div class="stack-list">
            <div class="stack-item">
              <strong>Morning coaching block</strong>
              <span>3 online check-ins, 2 live sessions, 1 onboarding call.</span>
            </div>
            <div class="stack-item">
              <strong>Programming focus</strong>
              <span>Advanced strength cohort moves from accumulation into intensification this week.</span>
            </div>
            <div class="stack-item">
              <strong>Business pulse</strong>
              <span>Revenue is concentrated in 5 high-ticket clients. Good month, but watch dependence.</span>
            </div>
          </div>
        </article>

        <article class="surface-card">
          <p class="card-label">Momentum</p>
          <h3>7-day client health trend</h3>
          <div class="bar-chart">
            ${[
              ["Training compliance", "92%", "92%"],
              ["Nutrition adherence", "84%", "84%"],
              ["Sleep score", "71%", "71%"],
              ["Message response", "97%", "97%"],
            ]
              .map(
                ([label, value, width]) => `
                  <div class="bar-row">
                    <span>${label}</span>
                    <div class="bar" style="--fill: ${width};"></div>
                    <span>${value}</span>
                  </div>
                `,
              )
              .join("")}
          </div>
          <p class="footer-note">
            Sleep is the weakest link this week. That likely affects readiness before volume stalls show up in training data.
          </p>
        </article>
      </div>
    `,
  },
  {
    id: "clients",
    label: "Clients",
    description: "Profiles, risk signals, and client roster management.",
    render: () => `
      <div class="module-grid clients-grid">
        <article class="surface-card list-card">
          <p class="card-label">Client Roster</p>
          <h3>Active coaching clients</h3>
          <div class="stack-list">
            ${[
              ["Maya Singh", "Fat loss phase / check-in today", "High adherence", "good"],
              ["Rohan KC", "Travel week / needs hotel plan", "Needs attention", "warn"],
              ["Ava Chen", "Strength block / invoice paid", "Stable", "good"],
              ["S. Thapa", "General fitness / overdue invoice", "Payment risk", "warn"],
            ]
              .map(
                ([name, detail, status, tone]) => `
                  <div class="client-row">
                    <div>
                      <strong>${name}</strong>
                      <span>${detail}</span>
                    </div>
                    <span>${status}</span>
                    <span class="badge ${tone}">${tone === "good" ? "Healthy" : "Review"}</span>
                  </div>
                `,
              )
              .join("")}
          </div>
        </article>

        <article class="surface-card detail-card">
          <p class="card-label">Selected Profile</p>
          <h3>Maya Singh</h3>
          <div class="panel-subgrid two-up">
            <div class="metric-chip">
              <strong>92%</strong>
              <span>program adherence</span>
            </div>
            <div class="metric-chip">
              <strong>-3.8kg</strong>
              <span>bodyweight change</span>
            </div>
            <div class="metric-chip">
              <strong>4.7 / 5</strong>
              <span>avg weekly energy score</span>
            </div>
            <div class="metric-chip">
              <strong>12</strong>
              <span>weeks on current block</span>
            </div>
          </div>
          <div class="stack-list">
            <div class="stack-item">
              <strong>Primary goal</strong>
              <span>Lose body fat while keeping squat strength stable.</span>
            </div>
            <div class="stack-item">
              <strong>Coach notes</strong>
              <span>Progress is strong. Keep daily steps high and use lower fatigue accessories this week.</span>
            </div>
            <div class="stack-item">
              <strong>Next action</strong>
              <span>Reply to today's form-check upload and shift conditioning to bike intervals.</span>
            </div>
          </div>
        </article>
      </div>
    `,
  },
  {
    id: "builder",
    label: "Builder",
    description: "A week-by-week training builder for personalized programming.",
    render: () => `
      <div class="module-grid builder-grid">
        <article class="surface-card builder-card">
          <p class="card-label">Week 5 Block</p>
          <h3>Lower + upper hybrid split</h3>
          <div class="program-grid">
            ${[
              ["Day 1", "Lower strength", "Front squat, RDL, split squat, calf raise"],
              ["Day 2", "Upper push/pull", "Bench press, chest-supported row, incline DB press"],
              ["Day 3", "Lower volume", "Leg press, ham curl, reverse lunge, sled drag"],
              ["Day 4", "Upper hypertrophy", "Pull-down, cable fly, lateral raise, curls"],
            ]
              .map(
                ([day, title, detail]) => `
                  <article class="program-day">
                    <header>
                      <h4>${day}</h4>
                      <span class="chip">${title}</span>
                    </header>
                    <p>${detail}</p>
                  </article>
                `,
              )
              .join("")}
          </div>
        </article>

        <article class="surface-card">
          <p class="card-label">Exercise Prescription</p>
          <h3>Auto-progression logic</h3>
          <div class="stack-list">
            <div class="exercise-row">
              <strong>Front Squat</strong>
              <span>5 x 3 @ 82% 1RM. Add 2.5kg if all sets hit target velocity.</span>
            </div>
            <div class="exercise-row">
              <strong>Romanian Deadlift</strong>
              <span>4 x 6 @ RPE 7.5. Hold load if hamstring soreness exceeds 3/5.</span>
            </div>
            <div class="exercise-row">
              <strong>Bench Press</strong>
              <span>4 x 5 @ 78% 1RM. Add 1 rep on final set if bar speed is stable.</span>
            </div>
            <div class="exercise-row">
              <strong>Sled Push</strong>
              <span>6 rounds x 20m. Swap to bike intervals during travel weeks.</span>
            </div>
          </div>
          <p class="footer-note">
            This is the part to turn into a true data model later: exercises, phases, progression rules, templates, and assignment history.
          </p>
        </article>
      </div>
    `,
  },
  {
    id: "nutrition",
    label: "Nutrition",
    description: "Meal structure, macro targets, and adherence tracking.",
    render: () => `
      <div class="module-grid nutrition-grid">
        <article class="surface-card">
          <p class="card-label">Targets</p>
          <h3>Daily nutrition structure</h3>
          <div class="macro-grid">
            <div class="macro-card">
              <strong>175g</strong>
              <span>protein</span>
            </div>
            <div class="macro-card">
              <strong>210g</strong>
              <span>carbs</span>
            </div>
            <div class="macro-card">
              <strong>58g</strong>
              <span>fat</span>
            </div>
          </div>
          <div class="stack-list">
            <div class="meal-row">
              <strong>Meal 1</strong>
              <span>Greek yogurt bowl, whey, berries, granola.</span>
            </div>
            <div class="meal-row">
              <strong>Meal 2</strong>
              <span>Chicken rice bowl with vegetables and olive oil.</span>
            </div>
            <div class="meal-row">
              <strong>Meal 3</strong>
              <span>Egg wrap and fruit before training.</span>
            </div>
            <div class="meal-row">
              <strong>Meal 4</strong>
              <span>Lean beef, potatoes, mixed greens.</span>
            </div>
          </div>
        </article>

        <article class="surface-card">
          <p class="card-label">Adherence</p>
          <h3>What you would review each week</h3>
          <div class="bar-chart">
            ${[
              ["Protein target", "94%", "94%"],
              ["Step count", "88%", "88%"],
              ["Hydration", "79%", "79%"],
              ["Weekend control", "72%", "72%"],
            ]
              .map(
                ([label, value, width]) => `
                  <div class="bar-row">
                    <span>${label}</span>
                    <div class="bar" style="--fill: ${width};"></div>
                    <span>${value}</span>
                  </div>
                `,
              )
              .join("")}
          </div>
          <div class="stack-list">
            <div class="stack-item">
              <strong>Coach decision</strong>
              <span>Weekend meals are the constraint. Keep calories steady but add a restaurant strategy template.</span>
            </div>
            <div class="stack-item">
              <strong>Automation opportunity</strong>
              <span>Trigger a reminder every Friday for clients with weekend adherence below 80%.</span>
            </div>
          </div>
        </article>
      </div>
    `,
  },
  {
    id: "comms",
    label: "Comms",
    description: "Messaging, check-ins, and response workflows around real coaching.",
    render: () => `
      <div class="module-grid comms-grid">
        <article class="surface-card">
          <p class="card-label">Conversation</p>
          <h3>Maya Singh</h3>
          <div class="message-thread">
            <div class="chat-bubble">
              Uploaded today's front squat video. Last set felt slower than usual.
            </div>
            <div class="chat-bubble outbound">
              I see it. Depth is clean, but fatigue is climbing. Keep the load, drop one back-off set, and leave 1 rep in reserve.
            </div>
            <div class="chat-bubble">
              Perfect. Also hitting my steps target every day this week.
            </div>
          </div>
        </article>

        <article class="surface-card">
          <p class="card-label">Inbox + Check-Ins</p>
          <h3>What needs a reply</h3>
          <div class="stack-list">
            <div class="thread-row">
              <div>
                <strong>Rohan KC</strong>
                <span>Asked for a hotel gym version of day 3.</span>
              </div>
              <span>7 min ago</span>
              <span class="badge warn">Reply</span>
            </div>
            <div class="thread-row">
              <div>
                <strong>Ava Chen</strong>
                <span>Shared progress photo and recovery notes.</span>
              </div>
              <span>18 min ago</span>
              <span class="badge">Review</span>
            </div>
            <div class="thread-row">
              <div>
                <strong>S. Thapa</strong>
                <span>No check-in submitted for 9 days.</span>
              </div>
              <span>Flagged</span>
              <span class="badge warn">Nudge</span>
            </div>
          </div>
        </article>
      </div>
    `,
  },
  {
    id: "ops",
    label: "Ops",
    description: "Billing, automations, and retention-focused business operations.",
    render: () => `
      <div class="module-grid ops-grid">
        <article class="surface-card ledger-card">
          <p class="card-label">Billing Ledger</p>
          <h3>Recent payment activity</h3>
          <div class="stack-list">
            <div class="invoice-row">
              <div>
                <strong>Ava Chen</strong>
                <span>Monthly premium coaching</span>
              </div>
              <span>$420 paid</span>
              <span class="badge good">Cleared</span>
            </div>
            <div class="invoice-row">
              <div>
                <strong>S. Thapa</strong>
                <span>Monthly coaching retainer</span>
              </div>
              <span>$180 due</span>
              <span class="badge warn">Overdue</span>
            </div>
            <div class="invoice-row">
              <div>
                <strong>Maya Singh</strong>
                <span>Nutrition add-on</span>
              </div>
              <span>$90 paid</span>
              <span class="badge good">Cleared</span>
            </div>
          </div>
        </article>

        <article class="surface-card">
          <p class="card-label">Automations</p>
          <h3>Reusable business workflows</h3>
          <div class="stack-list">
            <div class="workflow-row">
              <strong>New lead intake</strong>
              <span>Form submitted -> auto email -> call booking link -> onboarding checklist.</span>
            </div>
            <div class="workflow-row">
              <strong>Missed check-in</strong>
              <span>No submission in 7 days -> reminder -> coach review at day 9.</span>
            </div>
            <div class="workflow-row">
              <strong>Invoice overdue</strong>
              <span>Payment fails -> retry -> reminder -> manual outreach task.</span>
            </div>
            <div class="workflow-row">
              <strong>Recovery alert</strong>
              <span>Low sleep + low readiness -> flag client -> deload recommendation queue.</span>
            </div>
          </div>
        </article>
      </div>
    `,
  },
];

function injectBrand() {
  if (document.title.includes("Abhay Method")) {
    document.title = document.title.replace("Abhay Method", brand.brandName);
  }

  const mappings = [
    ["[data-brand-name]", brand.brandName],
    ["[data-brand-short]", brand.shortName],
    ["[data-coach-name]", brand.coachName],
    ["[data-brand-descriptor]", brand.descriptor],
  ];

  mappings.forEach(([selector, value]) => {
    document.querySelectorAll(selector).forEach((node) => {
      node.textContent = value;
    });
  });

  document.querySelectorAll("[data-current-year]").forEach((node) => {
    node.textContent = new Date().getFullYear();
  });
}

function renderLandingMetrics() {
  const container = document.querySelector("#landing-metrics");
  if (!container) return;

  container.innerHTML = landingMetrics
    .map(
      (metric) => `
        <article class="metric-pill">
          <strong>${metric.value}</strong>
          <span>${metric.label}</span>
        </article>
      `,
    )
    .join("");
}

function renderCards(containerSelector, items, cardClass) {
  const container = document.querySelector(containerSelector);
  if (!container) return;

  container.innerHTML = items
    .map(
      (item) => `
        <article class="surface-card ${cardClass}">
          <span class="chip">${item.tag}</span>
          <h3>${item.title}</h3>
          <p>${item.text}</p>
        </article>
      `,
    )
    .join("");
}

function renderModuleList() {
  const container = document.querySelector("#module-list");
  if (!container) return;

  container.innerHTML = dashboardModules
    .map((module) => `<li>${module.label}</li>`)
    .join("");
}

function renderDashboardKPIs() {
  const container = document.querySelector("#dashboard-kpis");
  if (!container) return;

  container.innerHTML = dashboardKPIs
    .map(
      (item) => `
        <article class="kpi-card">
          <small>${item.label}</small>
          <strong>${item.value}</strong>
          <span>${item.note}</span>
        </article>
      `,
    )
    .join("");
}

function renderList(containerSelector, items) {
  const container = document.querySelector(containerSelector);
  if (!container) return;

  container.innerHTML = items.map((item) => `<li>${item}</li>`).join("");
}

function renderDashboard() {
  const nav = document.querySelector("#dashboard-nav");
  const title = document.querySelector("#module-title");
  const description = document.querySelector("#module-description");
  const panel = document.querySelector("#dashboard-panel");

  if (!nav || !title || !description || !panel) return;

  let activeId = dashboardModules[0].id;

  function drawModule(id) {
    const activeModule = dashboardModules.find((module) => module.id === id) || dashboardModules[0];

    activeId = activeModule.id;
    title.textContent = activeModule.label;
    description.textContent = activeModule.description;
    panel.innerHTML = activeModule.render();

    nav.querySelectorAll("button").forEach((button) => {
      button.classList.toggle("active", button.dataset.module === activeId);
    });
  }

  nav.innerHTML = dashboardModules
    .map(
      (module) => `
        <button type="button" data-module="${module.id}">
          <span>${module.label}</span>
          <span aria-hidden="true">+</span>
        </button>
      `,
    )
    .join("");

  nav.addEventListener("click", (event) => {
    const target = event.target instanceof Element ? event.target : null;
    const button = target ? target.closest("button[data-module]") : null;
    if (!button) return;

    drawModule(button.dataset.module);
  });

  drawModule(activeId);
}

function initReveal() {
  const items = document.querySelectorAll(".reveal");
  if (!items.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      });
    },
    { threshold: 0.16 },
  );

  items.forEach((item) => observer.observe(item));
}

function init() {
  injectBrand();
  renderLandingMetrics();
  renderCards("#system-grid", systemCards, "system-card");
  renderCards("#feature-grid", features, "feature-card");
  renderModuleList();
  renderDashboardKPIs();
  renderList("#priority-list", priorityItems);
  renderList("#action-list", actionItems);
  renderDashboard();
  initReveal();
}

init();
