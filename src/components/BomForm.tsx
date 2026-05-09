/**
 * BomForm.tsx
 * -----------
 * Full-stack Bill of Materials management UI for
 * MANJULAB Ohio Data Center – PersonaPlex + LLM Brain + RAG (5 TPS scale)
 *
 * Usage:
 *   import { BomForm } from "./BomForm";
 *   <BomForm apiBase="http://localhost:4000/api" />
 */

import React, {
  FC,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import * as XLSX from "xlsx";

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

export type ComponentStatus = "Available" | "Missing" | "Can Build" | "Need Setup";

export interface BomComponent {
  id?: number;
  section: string;
  component: string;
  subcomponent?: string;
  vendor?: string;
  model?: string;
  specs?: Record<string, unknown>;
  quantity: number;
  unit_cost: number;
  total_cost?: number;
  notes?: string;
  status: ComponentStatus;
  updated_at?: string;
}

export interface Vendor {
  id: number;
  name: string;
  website?: string;
}

export interface ModelOption {
  id: number;
  name: string;
  specs_json?: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// Static catalogue – default components per section
// ─────────────────────────────────────────────────────────────────────────────

const SECTIONS = [
  "Infrastructure",
  "Voice Layer",
  "Brain Layer",
  "Knowledge Layer",
  "Session Layer",
  "Gateway Layer",
  "Client Layer",
  "Support Services",
  "Security",
  "Deployment",
] as const;

type SectionName = (typeof SECTIONS)[number];

const DEFAULT_COMPONENTS: Record<SectionName, string[]> = {
  Infrastructure: [
    "GPU Server",
    "CPU Server",
    "Storage Array",
    "Top-of-Rack Switch",
    "PDU",
    "UPS",
    "Rack Cabinet",
    "Cooling / CRAC",
  ],
  "Voice Layer": [
    "Speech-to-Text Engine",
    "Text-to-Speech Engine",
    "Audio Codec",
    "WebRTC Server",
    "Noise Cancellation",
  ],
  "Brain Layer": [
    "LLM Inference Server",
    "LLM Model",
    "Orchestration Framework",
    "Prompt Router",
    "Context Manager",
  ],
  "Knowledge Layer": [
    "Vector Database",
    "Embedding Model",
    "Document Store",
    "Chunking Pipeline",
    "Re-Ranker",
  ],
  "Session Layer": [
    "Session Manager",
    "In-Memory Cache",
    "Message Queue",
    "Conversation History DB",
  ],
  "Gateway Layer": [
    "API Gateway",
    "Load Balancer",
    "Reverse Proxy",
    "Rate Limiter",
    "Auth Service",
  ],
  "Client Layer": [
    "Web Client",
    "Mobile SDK",
    "Telephony Adapter",
    "Admin Dashboard",
  ],
  "Support Services": [
    "Metrics & Monitoring",
    "Log Aggregation",
    "Alerting",
    "CI/CD Pipeline",
    "Artifact Registry",
  ],
  Security: [
    "WAF",
    "Identity Provider / SSO",
    "Secrets Manager",
    "Certificate Manager",
    "DDoS Protection",
  ],
  Deployment: [
    "Container Orchestration",
    "Container Registry",
    "IaC Tool",
    "GitOps Controller",
    "Backup Solution",
  ],
};

// Vendor suggestions per component keyword (for fast-path default dropdowns)
const VENDOR_HINTS: Record<string, string[]> = {
  "GPU Server":          ["NVIDIA", "AMD", "Intel"],
  "CPU Server":          ["Intel", "AMD", "Dell", "SuperMicro"],
  "Storage Array":       ["NetApp", "Pure Storage", "Dell"],
  "Top-of-Rack Switch":  ["Cisco", "Arista", "Mellanox"],
  "PDU":                 ["APC", "Eaton"],
  "UPS":                 ["APC", "Eaton"],
  "Speech-to-Text Engine": ["AssemblyAI", "OpenAI"],
  "Text-to-Speech Engine": ["ElevenLabs"],
  "LLM Inference Server":  ["NVIDIA", "AMD"],
  "LLM Model":             ["OpenAI", "Meta", "Mistral AI"],
  "Vector Database":       ["Pinecone", "Weaviate", "Redis"],
  "In-Memory Cache":       ["Redis"],
  "API Gateway":           ["Kong", "Cloudflare"],
  "WAF":                   ["Cloudflare"],
  "IaC Tool":              ["HashiCorp"],
};

// ─────────────────────────────────────────────────────────────────────────────
// Status badge helper
// ─────────────────────────────────────────────────────────────────────────────

const STATUS_CLASSES: Record<ComponentStatus, string> = {
  Available:   "bg-green-100  text-green-800  border-green-300",
  Missing:     "bg-red-100    text-red-800    border-red-300",
  "Can Build": "bg-yellow-100 text-yellow-800 border-yellow-300",
  "Need Setup":"bg-blue-100   text-blue-800   border-blue-300",
};

const StatusBadge: FC<{ status: ComponentStatus }> = ({ status }: { status: ComponentStatus }) => (
  <span
    className={`inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-semibold ${STATUS_CLASSES[status]}`}
  >
    {status}
  </span>
);

// ─────────────────────────────────────────────────────────────────────────────
// Currency formatter
// ─────────────────────────────────────────────────────────────────────────────

const usd = (n: number) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
  }).format(n);

// ─────────────────────────────────────────────────────────────────────────────
// Main BomForm component
// ─────────────────────────────────────────────────────────────────────────────

interface BomFormProps {
  /** Base URL for the REST API, e.g. "http://localhost:4000/api" */
  apiBase?: string;
}

export const BomForm: FC<BomFormProps> = ({
  apiBase = "/api",
}) => {
  // ── State ───────────────────────────────────────────────────────
  const [components, setComponents]           = useState<BomComponent[]>([]);
  const [vendors, setVendors]                 = useState<Vendor[]>([]);
  const [models, setModels]                   = useState<ModelOption[]>([]);
  const [selectedSection, setSelectedSection] = useState<SectionName>("Infrastructure");
  const [selectedComp, setSelectedComp]       = useState<BomComponent | null>(null);
  const [formData, setFormData]               = useState<Partial<BomComponent>>({});
  const [saving, setSaving]                   = useState(false);
  const [error, setError]                     = useState<string | null>(null);
  const [success, setSuccess]                 = useState<string | null>(null);
  const [addingNew, setAddingNew]             = useState(false);
  const [newCompName, setNewCompName]         = useState("");
  const formRef                               = useRef<HTMLDivElement>(null);

  // ── Derived ─────────────────────────────────────────────────────
  const sectionComponents = useMemo(
    () => components.filter((c: BomComponent) => c.section === selectedSection),
    [components, selectedSection]
  );

  const sectionTotals = useMemo(() => {
    const totals: Record<string, number> = {};
    for (const c of components) {
      totals[c.section] = (totals[c.section] ?? 0) + (c.total_cost ?? c.quantity * c.unit_cost);
    }
    return totals;  }, [components]);

  const grandTotal = useMemo(
    () => (Object.values(sectionTotals) as number[]).reduce((a: number, b: number) => a + b, 0),
    [sectionTotals]
  );

  // ── Data fetching ────────────────────────────────────────────────
  const fetchComponents = useCallback(async () => {
    try {
      const res = await fetch(`${apiBase}/components`);
      if (!res.ok) throw new Error("Failed to fetch components");
      const data: BomComponent[] = await res.json();
      setComponents(data);
    } catch {
      // Silently fall through – offline / dev mode
    }
  }, [apiBase]);

  const fetchVendors = useCallback(async () => {
    try {
      const res = await fetch(`${apiBase}/vendors`);
      if (!res.ok) throw new Error("Failed to fetch vendors");
      setVendors(await res.json());
    } catch {
      // Provide a fallback vendor list so the UI is still usable offline
      setVendors(
        [
          "NVIDIA","AMD","Intel","Dell","SuperMicro","Cisco","Arista",
          "APC","Eaton","NetApp","Pure Storage","AssemblyAI","OpenAI",
          "ElevenLabs","Meta","Mistral AI","Pinecone","Weaviate","Redis",
          "Cloudflare","HashiCorp","Kong",
        ].map((name, i) => ({ id: i + 1, name }))
      );
    }
  }, [apiBase]);

  const fetchModels = useCallback(
    async (vendorName: string) => {
      setModels([]);
      if (!vendorName) return;
      try {
        const res = await fetch(
          `${apiBase}/models?vendor=${encodeURIComponent(vendorName)}`
        );
        if (!res.ok) return;
        setModels(await res.json());
      } catch {
        // ignore
      }
    },
    [apiBase]
  );

  useEffect(() => {
    void fetchComponents();
    void fetchVendors();
  }, [fetchComponents, fetchVendors]);

  // ── Select a component row ───────────────────────────────────────
  const handleSelectComponent = (comp: BomComponent) => {
    setSelectedComp(comp);
    setFormData({ ...comp });
    setAddingNew(false);
    setError(null);
    setSuccess(null);
    if (comp.vendor) void fetchModels(comp.vendor);
    formRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  // ── Form field changes ────────────────────────────────────────────
  const handleChange = (
    field: keyof BomComponent,
    value: string | number | ComponentStatus
  ) => {
    setFormData((prev: Partial<BomComponent>) => {
      const next: Partial<BomComponent> = { ...prev, [field]: value };
      if (field === "vendor") {
        next.model = "";
        void fetchModels(value as string);
      }
      if (field === "model") {
        const chosen = models.find((m: ModelOption) => m.name === value);
        next.specs = chosen?.specs_json ?? prev.specs;
      }
      return next;
    });
  };

  // ── Save ──────────────────────────────────────────────────────────
  const handleSave = async () => {
    if (!formData.component || !formData.section) {
      setError("Component name and section are required.");
      return;
    }
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const isNew = !formData.id;
      const url   = isNew
        ? `${apiBase}/components`
        : `${apiBase}/components/${formData.id}`;
      const method = isNew ? "POST" : "PUT";

      const res = await fetch(url, {
        method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(formData),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error ?? `HTTP ${res.status}`);
      }

      const saved: BomComponent = await res.json();

      setComponents((prev: BomComponent[]) =>
        isNew
          ? [...prev, saved]
          : prev.map((c: BomComponent) => (c.id === saved.id ? saved : c))
      );
      setSelectedComp(saved);
      setFormData(saved);
      setSuccess("Saved successfully!");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Save failed");
    } finally {
      setSaving(false);
    }
  };

  // ── Add component ─────────────────────────────────────────────────
  const handleAddComponent = () => {
    if (!newCompName.trim()) return;
    const blank: BomComponent = {
      section:   selectedSection,
      component: newCompName.trim(),
      quantity:  1,
      unit_cost: 0,
      status:    "Missing",
    };
    setSelectedComp(null);
    setFormData(blank);
    setAddingNew(false);
    setNewCompName("");
    setError(null);
    setSuccess(null);
  };

  // ── Delete component ──────────────────────────────────────────────
  const handleDelete = async (comp: BomComponent) => {
    if (!comp.id) {
      setComponents((prev: BomComponent[]) => prev.filter((c: BomComponent) => c !== comp));
      setSelectedComp(null);
      setFormData({});
      return;
    }
    if (!window.confirm(`Delete "${comp.component}"?`)) return;
    try {
      const res = await fetch(`${apiBase}/components/${comp.id}`, {
        method: "DELETE",
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setComponents((prev: BomComponent[]) => prev.filter((c: BomComponent) => c.id !== comp.id));
      if (selectedComp?.id === comp.id) {
        setSelectedComp(null);
        setFormData({});
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Delete failed");
    }
  };

  // ── Export to Excel ───────────────────────────────────────────────
  const handleExportToExcel = () => {
    if (components.length === 0) {
      setError("No components to export.");
      return;
    }
    const exportData = components.map((c) => ({
      Section: c.section,
      Component: c.component,
      Subcomponent: c.subcomponent ?? "",
      Vendor: c.vendor ?? "",
      Model: c.model ?? "",
      Quantity: c.quantity,
      "Unit Cost": c.unit_cost,
      "Total Cost": c.total_cost ?? c.quantity * c.unit_cost,
      Status: c.status,
      Notes: c.notes ?? "",
    }));
    const worksheet = XLSX.utils.json_to_sheet(exportData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "BoM");
    XLSX.writeFile(workbook, "MANJULAB_Ohio_BOM.xlsx");
  };

  // ── Vendor dropdown options ───────────────────────────────────────
  const vendorOptions = useMemo(() => {
    const hints = formData.component
      ? (VENDOR_HINTS[formData.component] ?? [])
      : [];
    const hintSet = new Set(hints);
    const rest = vendors.filter((v: Vendor) => !hintSet.has(v.name)).map((v: Vendor) => v.name);
    return [...hints, ...rest];
  }, [vendors, formData.component]);

  // ── Spec highlights ───────────────────────────────────────────────
  const specEntries = useMemo(() => {
    const specs = formData.specs;
    if (!specs || typeof specs !== "object") return [];
    return Object.entries(specs).slice(0, 6);
  }, [formData.specs]);

  // ─────────────────────────────────────────────────────────────────
  // Render
  // ─────────────────────────────────────────────────────────────────
  return (
    <div className="flex h-screen flex-col bg-gray-50 font-sans text-gray-900">
      {/* ── Top bar ── */}
      <header className="flex items-center gap-3 border-b bg-white px-6 py-3 shadow-sm">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-indigo-600 text-white font-bold text-sm">
          BoM
        </div>
        <div>
          <h1 className="text-lg font-bold leading-tight">MANJULAB Ohio Data Center</h1>
          <p className="text-xs text-gray-500">
            Bill of Materials — PersonaPlex + LLM Brain + RAG (5 TPS)
          </p>
        </div>
        <div className="ml-auto flex items-center gap-6 text-right">
          <button
            onClick={handleExportToExcel}
            className="rounded bg-indigo-100 px-4 py-2 text-sm font-semibold text-indigo-700 hover:bg-indigo-200 transition-colors"
          >
            Export to Excel
          </button>
          <div>
            <p className="text-xs text-gray-400">Grand Total</p>
            <p className="text-xl font-bold text-indigo-700">{usd(grandTotal)}</p>
          </div>
        </div>
      </header>

      {/* ── Main body ── */}
      <div className="flex flex-1 overflow-hidden">

        {/* ── LEFT PANEL – Section sidebar ── */}
        <aside className="flex w-64 flex-col border-r bg-white">
          <div className="px-4 py-3 text-xs font-semibold uppercase tracking-widest text-gray-400">
            Sections
          </div>
          <nav className="flex-1 overflow-y-auto">
            {SECTIONS.map((section) => {
              const count   = components.filter((c: BomComponent) => c.section === section).length;
              const missing = components.filter(
                (c: BomComponent) => c.section === section && c.status === "Missing"
              ).length;
              const isActive = selectedSection === section;
              return (
                <button
                  key={section}
                  onClick={() => {
                    setSelectedSection(section);
                    setSelectedComp(null);
                    setFormData({});
                    setError(null);
                    setSuccess(null);
                  }}
                  className={`group flex w-full items-center justify-between px-4 py-2.5 text-sm transition-colors ${
                    isActive
                      ? "bg-indigo-50 font-semibold text-indigo-700"
                      : "text-gray-700 hover:bg-gray-50"
                  }`}
                >
                  <span className="truncate">{section}</span>
                  <span className="flex items-center gap-1">
                    {missing > 0 && (
                      <span className="rounded-full bg-red-100 px-1.5 py-0.5 text-xs font-bold text-red-700">
                        {missing}
                      </span>
                    )}
                    {count > 0 && (
                      <span className="rounded-full bg-gray-100 px-1.5 py-0.5 text-xs text-gray-500">
                        {count}
                      </span>
                    )}
                  </span>
                </button>
              );
            })}
          </nav>
        </aside>

        {/* ── CENTRE PANEL – Component list + form ── */}
        <main className="flex flex-1 flex-col overflow-hidden">
          <div className="flex flex-1 overflow-hidden">

            {/* Component list for selected section */}
            <div className="flex w-80 flex-col border-r bg-white">
              <div className="flex items-center justify-between border-b px-4 py-2.5">
                <span className="text-sm font-semibold">{selectedSection}</span>
                <button
                  onClick={() => setAddingNew((v: boolean) => !v)}
                  className="rounded bg-indigo-600 px-2 py-1 text-xs font-medium text-white hover:bg-indigo-700"
                >
                  + Add
                </button>
              </div>

              {/* Inline "add component" input */}
              {addingNew && (
                <div className="border-b p-3 flex gap-2">
                  <input
                    className="flex-1 rounded border px-2 py-1 text-sm focus:outline-none focus:ring-1 focus:ring-indigo-400"
                    placeholder="Component name…"
                    value={newCompName}
                    onChange={(e) => setNewCompName(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && handleAddComponent()}
                    autoFocus
                  />
                  <button
                    onClick={handleAddComponent}
                    className="rounded bg-indigo-600 px-2 py-1 text-xs text-white hover:bg-indigo-700"
                  >
                    OK
                  </button>
                </div>
              )}

              {/* Default catalogue items (if no DB rows yet for this section) */}
              <div className="flex-1 overflow-y-auto divide-y">
                {(() => {
                  const dbItems = sectionComponents;
                  const defaults = (DEFAULT_COMPONENTS as Record<string, string[]>)[selectedSection] ?? [];
                  const dbNames = new Set(dbItems.map((c: BomComponent) => c.component));
                  const placeholders = defaults.filter((d: string) => !dbNames.has(d));
                  const allItems: Array<BomComponent | string> = [...dbItems, ...placeholders];

                  if (allItems.length === 0) {
                    return (
                      <p className="p-4 text-xs text-gray-400">
                        No components. Click "+ Add" to create one.
                      </p>
                    );
                  }

                  return allItems.map((item, idx) => {
                    const isPlaceholder = typeof item === "string";
                    const isSelected =
                      !isPlaceholder &&
                      selectedComp?.id === (item as BomComponent).id &&
                      selectedComp?.component === (item as BomComponent).component;

                    if (isPlaceholder) {
                      return (
                        <button
                          key={`ph-${idx}`}
                          onClick={() => {
                            const blank: BomComponent = {
                              section:   selectedSection,
                              component: item,
                              quantity:  1,
                              unit_cost: 0,
                              status:    "Missing",
                            };
                            setSelectedComp(null);
                            setFormData(blank);
                            setError(null);
                            setSuccess(null);
                          }}
                          className="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-gray-400 hover:bg-gray-50"
                        >
                          <span className="flex-1 text-left truncate">{item}</span>
                          <StatusBadge status="Missing" />
                        </button>
                      );
                    }

                    const comp = item as BomComponent;
                    return (
                      <div
                        key={comp.id ?? `new-${idx}`}
                        className={`group flex items-center gap-2 px-4 py-2.5 text-sm transition-colors ${
                          isSelected
                            ? "bg-indigo-50"
                            : "hover:bg-gray-50"
                        }`}
                      >
                        <button
                          className="flex-1 text-left"
                          onClick={() => handleSelectComponent(comp)}
                        >
                          <p className={`truncate font-medium ${isSelected ? "text-indigo-700" : ""}`}>
                            {comp.component}
                          </p>
                          {comp.vendor && (
                            <p className="text-xs text-gray-400 truncate">
                              {comp.vendor} {comp.model ? `/ ${comp.model}` : ""}
                            </p>
                          )}
                        </button>
                        <StatusBadge status={comp.status} />
                        <button
                          onClick={() => handleDelete(comp)}
                          className="ml-1 hidden text-gray-300 hover:text-red-500 group-hover:block"
                          title="Delete"
                        >
                          ✕
                        </button>
                      </div>
                    );
                  });
                })()}
              </div>

              {/* Section cost footer */}
              <div className="border-t px-4 py-2 text-xs text-gray-500">
                Section total:{" "}
                <span className="font-semibold text-gray-700">
                  {usd(sectionTotals[selectedSection] ?? 0)}
                </span>
              </div>
            </div>

            {/* ── RIGHT PANEL – Dynamic form ── */}
            <div className="flex-1 overflow-y-auto p-6" ref={formRef}>
              {!formData.component ? (
                <div className="flex h-full items-center justify-center text-gray-300">
                  <div className="text-center">
                    <div className="text-5xl mb-3">📋</div>
                    <p className="text-lg">Select or add a component</p>
                  </div>
                </div>
              ) : (
                <div className="mx-auto max-w-2xl space-y-6">

                  {/* ── Card header ── */}
                  <div className="rounded-xl border bg-white p-5 shadow-sm">
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <h2 className="text-xl font-bold">{formData.component}</h2>
                        <p className="text-sm text-gray-500">{formData.section}</p>
                      </div>
                      <div className="flex items-center gap-2">
                        <select
                          value={formData.status ?? "Missing"}
                          onChange={(e) =>
                            handleChange("status", e.target.value as ComponentStatus)
                          }
                          className="rounded-lg border px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-indigo-400"
                        >
                          <option>Available</option>
                          <option>Missing</option>
                          <option>Can Build</option>
                          <option>Need Setup</option>
                        </select>
                        <StatusBadge status={(formData.status ?? "Missing") as ComponentStatus} />
                      </div>
                    </div>
                  </div>

                  {/* ── Vendor + Model ── */}
                  <div className="rounded-xl border bg-white p-5 shadow-sm space-y-4">
                    <h3 className="font-semibold text-gray-700">Vendor & Model</h3>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="mb-1 block text-xs font-medium text-gray-500">
                          Vendor
                        </label>
                        <select
                          value={formData.vendor ?? ""}
                          onChange={(e) => handleChange("vendor", e.target.value)}
                          className="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
                        >
                          <option value="">— select vendor —</option>
                          {vendorOptions.map((v: string) => (
                            <option key={v} value={v}>
                              {v}
                            </option>
                          ))}
                        </select>
                      </div>
                      <div>
                        <label className="mb-1 block text-xs font-medium text-gray-500">
                          Model
                        </label>
                        <select
                          value={formData.model ?? ""}
                          onChange={(e) => handleChange("model", e.target.value)}
                          className="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
                          disabled={models.length === 0}
                        >
                          <option value="">
                            {models.length === 0
                              ? "— choose vendor first —"
                              : "— select model —"}
                          </option>
                          {models.map((m: ModelOption) => (
                            <option key={m.id} value={m.name}>
                              {m.name}
                            </option>
                          ))}
                        </select>
                      </div>
                    </div>

                    {/* Subcomponent */}
                    <div>
                      <label className="mb-1 block text-xs font-medium text-gray-500">
                        Sub-component / SKU
                      </label>
                      <input
                        type="text"
                        value={formData.subcomponent ?? ""}
                        onChange={(e) => handleChange("subcomponent", e.target.value)}
                        placeholder="e.g. DGX H100 80GB NVL"
                        className="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
                      />
                    </div>
                  </div>

                  {/* ── Spec highlights (static, read-only) ── */}
                  {specEntries.length > 0 && (
                    <div className="rounded-xl border bg-indigo-50 p-5 shadow-sm">
                      <h3 className="mb-3 font-semibold text-indigo-700">Spec Highlights</h3>
                      <dl className="grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
                        {specEntries.map(([k, v]: [string, unknown]) => (
                          <div key={k} className="flex justify-between">
                            <dt className="text-gray-500 capitalize">
                              {k.replace(/_/g, " ")}
                            </dt>
                            <dd className="font-semibold text-gray-800">{String(v)}</dd>
                          </div>
                        ))}
                      </dl>
                    </div>
                  )}

                  {/* ── Quantity & Cost ── */}
                  <div className="rounded-xl border bg-white p-5 shadow-sm space-y-4">
                    <h3 className="font-semibold text-gray-700">Quantity & Cost</h3>
                    <div className="grid grid-cols-3 gap-4">
                      <div>
                        <label className="mb-1 block text-xs font-medium text-gray-500">
                          Quantity
                        </label>
                        <input
                          type="number"
                          min={1}
                          value={formData.quantity ?? 1}
                          onChange={(e) =>
                            handleChange("quantity", Math.max(1, parseInt(e.target.value) || 1))
                          }
                          className="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
                        />
                      </div>
                      <div>
                        <label className="mb-1 block text-xs font-medium text-gray-500">
                          Unit Cost (USD)
                        </label>
                        <input
                          type="number"
                          min={0}
                          step={0.01}
                          value={formData.unit_cost ?? 0}
                          onChange={(e) =>
                            handleChange("unit_cost", parseFloat(e.target.value) || 0)
                          }
                          className="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
                        />
                      </div>
                      <div>
                        <label className="mb-1 block text-xs font-medium text-gray-500">
                          Total Cost
                        </label>
                        <div className="w-full rounded-lg border bg-gray-50 px-3 py-2 text-sm font-semibold text-indigo-700">
                          {usd(
                            (formData.quantity ?? 1) * (formData.unit_cost ?? 0)
                          )}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* ── Notes ── */}
                  <div className="rounded-xl border bg-white p-5 shadow-sm">
                    <label className="mb-1 block text-xs font-medium text-gray-500">
                      Notes
                    </label>
                    <textarea
                      rows={3}
                      value={formData.notes ?? ""}
                      onChange={(e) => handleChange("notes", e.target.value)}
                      placeholder="Procurement notes, PO numbers, caveats…"
                      className="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 resize-none"
                    />
                  </div>

                  {/* ── Actions ── */}
                  <div className="flex items-center gap-3">
                    <button
                      onClick={handleSave}
                      disabled={saving}
                      className="rounded-lg bg-indigo-600 px-5 py-2 text-sm font-semibold text-white shadow hover:bg-indigo-700 disabled:opacity-60"
                    >
                      {saving ? "Saving…" : formData.id ? "Update" : "Save"}
                    </button>
                    {selectedComp && (
                      <button
                        onClick={() => handleDelete(selectedComp)}
                        className="rounded-lg border border-red-300 px-5 py-2 text-sm font-semibold text-red-600 hover:bg-red-50"
                      >
                        Delete
                      </button>
                    )}
                    <button
                      onClick={() => {
                        setSelectedComp(null);
                        setFormData({});
                        setError(null);
                        setSuccess(null);
                      }}
                      className="rounded-lg border px-5 py-2 text-sm font-semibold text-gray-600 hover:bg-gray-50"
                    >
                      Cancel
                    </button>
                  </div>

                  {/* Feedback */}
                  {error && (
                    <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-700">
                      {error}
                    </div>
                  )}
                  {success && (
                    <div className="rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-700">
                      {success}
                    </div>
                  )}

                  {/* Updated at */}
                  {formData.updated_at && (
                    <p className="text-xs text-gray-400">
                      Last updated: {new Date(formData.updated_at).toLocaleString()}
                    </p>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* ── SUMMARY TABLE ── */}
          <div className="border-t bg-white">
            <div className="px-6 py-3">
              <h3 className="mb-3 font-semibold text-gray-700">Cost Summary</h3>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b text-left text-xs uppercase tracking-wide text-gray-400">
                      <th className="pb-2 pr-6">Section</th>
                      <th className="pb-2 pr-6 text-right">Components</th>
                      <th className="pb-2 pr-6 text-right">Missing</th>
                      <th className="pb-2 text-right">Total Cost</th>
                    </tr>
                  </thead>
                  <tbody>
                    {SECTIONS.map((section) => {
                      const items   = components.filter((c: BomComponent) => c.section === section);
                      const missing = items.filter((c: BomComponent) => c.status === "Missing").length;
                      const total   = sectionTotals[section] ?? 0;
                      return (
                        <tr
                          key={section}
                          className={`border-b last:border-0 hover:bg-gray-50 cursor-pointer ${
                            selectedSection === section ? "bg-indigo-50" : ""
                          }`}
                          onClick={() => setSelectedSection(section)}
                        >
                          <td className="py-1.5 pr-6 font-medium">{section}</td>
                          <td className="py-1.5 pr-6 text-right text-gray-500">
                            {items.length}
                          </td>
                          <td className="py-1.5 pr-6 text-right">
                            {missing > 0 ? (
                              <span className="font-semibold text-red-600">{missing}</span>
                            ) : (
                              <span className="text-gray-300">—</span>
                            )}
                          </td>
                          <td className="py-1.5 text-right font-semibold">
                            {usd(total)}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                  <tfoot>
                    <tr className="border-t-2 border-indigo-200 bg-indigo-50">
                      <td colSpan={3} className="py-2 font-bold text-indigo-700">
                        Grand Total
                      </td>
                      <td className="py-2 text-right text-lg font-bold text-indigo-700">
                        {usd(grandTotal)}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
};

export default BomForm;
