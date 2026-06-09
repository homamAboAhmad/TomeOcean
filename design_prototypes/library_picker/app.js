const books = [
  ["السيرة النبوية الفرنسية", "مؤلف غير محدد"],
  ["حوار هادئ مع الصوفية", "مؤلف غير محدد"],
  ["ex10_50p", "مؤلف غير محدد"],
  ["الجامع", "مؤلف غير محدد"],
  ["روضة", "مؤلف غير محدد"],
  ["اشتراطات 1", "مؤلف غير محدد"],
  ["اشتراطات 2", "مؤلف غير محدد"],
  ["ex3_test", "مؤلف غير محدد"],
  ["أبو حفص، رجال الموطأ", "أبو حفص"],
  ["أعمال عبد العزيز بن شاكر الرافعي", "عبد العزيز بن شاكر الرافعي"],
  ["أكثر من ألف سنة في اليوم والليلة", "خالد الحسينان"],
  ["الأرشيف الجامع لكلمات وخطابات الشيخ أبي مصعب الزرقاوي", "شبكة البراق الإسلامية"],
  ["البرامج العملية للحياة اليومية", "مؤلف غير محدد"],
  ["الشريعة الإسلامية وفقه التطبيق", "مؤلف غير محدد"],
];

const tabs = [
  ["books", "الكتب", "books"],
  ["sections", "التصنيف", "categories"],
  ["authors", "المؤلفون", "authors"],
  ["favorites", "المفضلة", "star"],
  ["recent", "مؤخرًا", "clock"],
];

const entities = {
  sections: ["العقيدة", "الفقه وأصوله", "الحديث وعلومه", "السيرة والتاريخ", "اللغة العربية"],
  authors: ["ابن تيمية", "ابن القيم", "الذهبي", "النووي", "ابن كثير"],
};

let activeTab = "books";
let searchValue = "";
let selectedBook = books[5][0];
const favorites = new Set([books[5][0], books[10][0], books[11][0]]);

const sidebar = document.querySelector("#sidebar");
const toolbar = document.querySelector("#toolbar");
const content = document.querySelector("#content");

function icon(id) {
  return `<svg aria-hidden="true"><use href="#${id}"></use></svg>`;
}

function renderSidebar() {
  sidebar.innerHTML = tabs.map(([id, label, iconId]) => `
    <button class="tab ${activeTab === id ? "active" : ""}" data-tab="${id}">
      ${icon(iconId)}<span>${label}</span>
    </button>`).join("");

  sidebar.querySelectorAll(".tab").forEach(button => {
    button.addEventListener("click", () => {
      activeTab = button.dataset.tab;
      render();
    });
  });
}

function renderToolbar() {
  if (activeTab === "sections") {
    toolbar.className = "toolbar filter-toolbar";
    toolbar.innerHTML = `
      <section class="type-group">
        <label class="group-title">المطبوعات <input type="checkbox" checked></label>
        <div class="chips">
          <button class="type-chip active">${icon("book-outline")}كتاب</button>
          <button class="type-chip active">${icon("magazine")}مجلة</button>
          <label class="inline-check"><input type="checkbox" checked> يوافق المطبوع</label>
          <label class="inline-check"><input type="checkbox" checked> لا يوافق المطبوع</label>
        </div>
      </section>
      <section class="type-group">
        <label class="group-title">غير المطبوعات <input type="checkbox" checked></label>
        <div class="chips">
          <button class="type-chip active">${icon("manuscript")}مخطوط</button>
          <button class="type-chip active">${icon("school")}رسالة جامعية</button>
          <button class="type-chip active">${icon("storage")}إلكترونية</button>
          <button class="type-chip active">${icon("album")}تفريغات</button>
        </div>
      </section>`;
    return;
  }
  if (activeTab === "authors") {
    toolbar.className = "toolbar";
    toolbar.innerHTML = "";
    return;
  }

  toolbar.className = "toolbar";
  toolbar.innerHTML = `
    <button class="icon-button" title="بطاقة الكتاب">${icon("book-card")}</button>
    <button class="icon-button" title="إضافة كتب">${icon("add-book")}</button>
    <button class="icon-button" title="نطاق البحث">${icon("settings")}</button>
    <label class="search">${icon("search")}
      <input value="${searchValue}" placeholder="يمكن البحث بجزء من اسم الكتاب أو المؤلف أو كليهما">
    </label>`;
  toolbar.querySelector("input").addEventListener("input", event => {
    searchValue = event.target.value;
    renderContent();
  });
}

function filteredBooks() {
  let list = books;
  if (activeTab === "favorites") list = list.filter(([title]) => favorites.has(title));
  if (activeTab === "recent") list = list.slice(3, 12);
  const query = searchValue.trim();
  if (query) list = list.filter(item => item.join(" ").includes(query));
  return list;
}

function rowsHtml(list, compact = false) {
  return list.map(([title, author]) => `
    <div class="book-row ${selectedBook === title ? "selected" : ""}" data-title="${title}">
      <div class="cell">${title}</div>
      <div class="column-handle" title="اسحب لتغيير عرض العمود"></div>
      <div class="cell author">${author}</div>
      ${activeTab === "recent"
        ? `<button class="delete" title="حذف من مؤخرًا">${icon("trash")}</button>`
        : `<button class="favorite ${favorites.has(title) ? "on" : ""}" title="المفضلة">${favorites.has(title) ? "★" : "☆"}</button>`}
    </div>`).join("");
}

function tableHtml(list) {
  return `<div class="books-layout">
    <div class="table-header">
      <div class="cell">الكتاب</div>
      <div class="column-handle" title="اسحب لتغيير عرض العمود"></div>
      <div class="cell author">المؤلف</div>
      <div></div>
    </div>
    <div class="rows">${rowsHtml(list)}</div>
  </div>`;
}

function splitHtml(type) {
  const label = type === "sections" ? "التصنيفات" : "المؤلفون";
  const subLabel = type === "sections" ? "كتب التصنيف" : "كتب المؤلف";
  const entityContent = type === "authors" ? authorsTableHtml() : `
    <div class="pane-title"><strong>${label}</strong><span>العدد</span></div>
    <div class="pane-search"><input placeholder="بحث في ${label}"></div>
    <div class="rows">${entities[type].map((name, index) => `
      <div class="entity-row ${index === 0 ? "active" : ""}">
        <span>${name}</span><span class="count">${(index + 1) * 24}</span>
      </div>`).join("")}
    </div>`;
  return `<div class="split-view">
    <section class="pane">
      <div class="pane-title"><strong>${subLabel}</strong><span>${books.length} كتابًا</span></div>
      <div class="pane-search"><input placeholder="بحث في ${subLabel}"></div>
      <div class="rows">${rowsHtml(books.slice(0, 10), true)}</div>
    </section>
    <div class="split-handle" title="اسحب لتغيير عرض اللوحتين"></div>
    <section class="pane">
      ${entityContent}
    </section>
  </div>`;
}

function authorsTableHtml() {
  const deaths = ["728 هـ", "751 هـ", "748 هـ", "676 هـ", "774 هـ"];
  return `<div class="pane-search"><input placeholder="بحث في المؤلفين"></div>
    <div class="entities-table">
      <div class="entities-header">
        <div class="entity-cell center">المؤلف</div><div class="entity-divider" title="تغيير عرض عمود المؤلف"></div>
        <div class="entity-cell center">الوفاة</div><div class="entity-divider" title="تغيير عرض عمود الكتب"></div>
        <div class="entity-cell center">الكتب</div>
      </div>
      ${entities.authors.map((name, index) => `<div class="entity-data-row ${index === 0 ? "active" : ""}">
        <div class="entity-cell">${name}</div><div></div>
        <div class="entity-cell center">${deaths[index]}</div><div></div>
        <div class="entity-cell center">${(index + 1) * 24}</div>
      </div>`).join("")}
    </div>`;
}

function renderContent() {
  content.innerHTML = ["sections", "authors"].includes(activeTab)
    ? splitHtml(activeTab)
    : tableHtml(filteredBooks());
  wireRows();
  wireColumnResize();
  wireSplitResize();
  wireEntityResize();
}

function wireEntityResize() {
  const table = content.querySelector(".entities-table");
  if (!table) return;
  const handles = table.querySelectorAll(".entities-header .entity-divider");
  handles.forEach((handle, index) => handle.addEventListener("pointerdown", event => {
    const startX = event.clientX;
    const startTitle = parseFloat(getComputedStyle(table).getPropertyValue("--title-ratio")) || 54;
    const startCount = parseFloat(getComputedStyle(table).getPropertyValue("--count-width")) || 58;
    const move = e => {
      const delta = e.clientX - startX;
      if (index === 0) {
        table.style.setProperty("--title-ratio", `${Math.min(72, Math.max(35, startTitle - delta / table.clientWidth * 100))}%`);
      } else {
        table.style.setProperty("--count-width", `${Math.min(140, Math.max(45, startCount + delta))}px`);
      }
    };
    const end = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", end);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", end);
  }));
}

function wireRows() {
  content.querySelectorAll(".book-row").forEach(row => {
    row.addEventListener("click", event => {
      if (event.target.closest("button")) return;
      selectedBook = row.dataset.title;
      renderContent();
    });
    const favorite = row.querySelector(".favorite");
    favorite?.addEventListener("click", () => {
      favorites.has(row.dataset.title) ? favorites.delete(row.dataset.title) : favorites.add(row.dataset.title);
      renderContent();
    });
  });
}

function wireColumnResize() {
  const handles = content.querySelectorAll(".column-handle");
  handles.forEach(handle => handle.addEventListener("pointerdown", event => {
    event.preventDefault();
    const startX = event.clientX;
    const host = handle.closest(".books-layout, .pane");
    const width = host.clientWidth;
    const row = handle.parentElement;
    const start = parseFloat(getComputedStyle(row).getPropertyValue("--book-ratio")) || 64;
    const move = e => {
      const next = Math.min(80, Math.max(30, start - ((e.clientX - startX) / width) * 100));
      host.querySelectorAll(".table-header, .book-row").forEach(item => item.style.setProperty("--book-ratio", `${next}%`));
    };
    const end = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", end);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", end);
  }));
}

function wireSplitResize() {
  const handle = content.querySelector(".split-handle");
  if (!handle) return;
  handle.addEventListener("pointerdown", event => {
    const split = handle.parentElement;
    const startX = event.clientX;
    const start = parseFloat(getComputedStyle(split).getPropertyValue("--entity-width")) || 33;
    const move = e => {
      const next = Math.min(60, Math.max(24, start - ((e.clientX - startX) / split.clientWidth) * 100));
      split.style.setProperty("--entity-width", `${next}%`);
    };
    const end = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", end);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", end);
  });
}

function render() {
  renderSidebar();
  renderToolbar();
  renderContent();
}

render();
