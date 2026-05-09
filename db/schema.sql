-- ============================================================
-- MANJULAB Ohio Data Center – BoM Database Schema
-- PersonaPlex + LLM Brain + RAG  (5 TPS scale)
-- ============================================================

-- Vendors ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS vendors (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(255) NOT NULL UNIQUE,
    website    VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Models ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS models (
    id          SERIAL PRIMARY KEY,
    vendor_id   INTEGER NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    name        VARCHAR(255) NOT NULL,
    specs_json  JSONB,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (vendor_id, name)
);

-- Components (main BoM table) -------------------------------------
CREATE TABLE IF NOT EXISTS components (
    id            SERIAL PRIMARY KEY,
    section       VARCHAR(255)   NOT NULL,
    component     VARCHAR(255)   NOT NULL,
    subcomponent  VARCHAR(255),
    vendor        VARCHAR(255),
    model         VARCHAR(255),
    specs         JSONB,
    quantity      INTEGER        NOT NULL DEFAULT 1,
    unit_cost     NUMERIC(14,2)  NOT NULL DEFAULT 0,
    total_cost    NUMERIC(14,2)  GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    notes         TEXT,
    status        VARCHAR(50)    NOT NULL DEFAULT 'Missing'
                  CHECK (status IN ('Available','Missing','Can Build','Need Setup')),
    updated_at    TIMESTAMP      NOT NULL DEFAULT NOW()
);

-- Costs (price history / overrides) ------------------------------
CREATE TABLE IF NOT EXISTS costs (
    id              SERIAL PRIMARY KEY,
    component_id    INTEGER NOT NULL REFERENCES components(id) ON DELETE CASCADE,
    source_url      VARCHAR(500),
    fetched_price   NUMERIC(14,2),
    manual_override NUMERIC(14,2),
    fetched_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes ---------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_components_section  ON components (section);
CREATE INDEX IF NOT EXISTS idx_models_vendor_id    ON models (vendor_id);
CREATE INDEX IF NOT EXISTS idx_costs_component_id  ON costs (component_id);

-- ============================================================
-- Seed Data – Vendors
-- ============================================================
INSERT INTO vendors (name, website) VALUES
  ('NVIDIA',        'https://www.nvidia.com'),
  ('AMD',           'https://www.amd.com'),
  ('Intel',         'https://www.intel.com'),
  ('Dell',          'https://www.dell.com'),
  ('SuperMicro',    'https://www.supermicro.com'),
  ('Cisco',         'https://www.cisco.com'),
  ('Arista',        'https://www.arista.com'),
  ('APC',           'https://www.apc.com'),
  ('Eaton',         'https://www.eaton.com'),
  ('NetApp',        'https://www.netapp.com'),
  ('Pure Storage',  'https://www.purestorage.com'),
  ('Mellanox',      'https://www.mellanox.com'),
  ('AssemblyAI',    'https://www.assemblyai.com'),
  ('OpenAI',        'https://www.openai.com'),
  ('ElevenLabs',    'https://www.elevenlabs.io'),
  ('Meta',          'https://ai.meta.com'),
  ('Mistral AI',    'https://mistral.ai'),
  ('Pinecone',      'https://www.pinecone.io'),
  ('Weaviate',      'https://weaviate.io'),
  ('Redis',         'https://redis.io'),
  ('Cloudflare',    'https://www.cloudflare.com'),
  ('HashiCorp',     'https://www.hashicorp.com'),
  ('VMware',        'https://www.vmware.com'),
  ('Kubernetes',    'https://kubernetes.io'),
  ('Kong',          'https://konghq.com')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- Seed Data – Models
-- ============================================================
INSERT INTO models (vendor_id, name, specs_json)
SELECT v.id, m.name, m.specs::jsonb
FROM vendors v
JOIN (VALUES
  ('NVIDIA', 'H100 SXM5 80GB',     '{"gpu_memory":"80 GB HBM3","tflops_fp16":1979,"power_draw_w":700,"interconnect":"NVLink 4.0"}'),
  ('NVIDIA', 'A100 SXM4 80GB',     '{"gpu_memory":"80 GB HBM2e","tflops_fp16":312,"power_draw_w":400,"interconnect":"NVLink 3.0"}'),
  ('NVIDIA', 'L40S',                '{"gpu_memory":"48 GB GDDR6","tflops_fp16":733,"power_draw_w":350,"interconnect":"PCIe 4.0"}'),
  ('AMD',    'MI300X',              '{"gpu_memory":"192 GB HBM3","tflops_fp16":1307,"power_draw_w":750,"interconnect":"Infinity Fabric"}'),
  ('AMD',    'MI250X',              '{"gpu_memory":"128 GB HBM2e","tflops_fp16":383,"power_draw_w":560,"interconnect":"Infinity Fabric"}'),
  ('Intel',  'Gaudi 2',             '{"gpu_memory":"96 GB HBM2e","tflops_bf16":865,"power_draw_w":600,"interconnect":"RoCE"}'),
  ('Intel',  'Xeon Platinum 8480+', '{"cores":60,"threads":120,"base_ghz":2.0,"tdp_w":350,"ram_channels":8}'),
  ('AMD',    'EPYC 9654',           '{"cores":96,"threads":192,"base_ghz":2.4,"tdp_w":360,"ram_channels":12}'),
  ('Dell',   'PowerEdge R750xa',    '{"form_factor":"2U","max_gpus":4,"max_ram_gb":2048,"storage":"32x 2.5\" NVMe"}'),
  ('SuperMicro','AS-4125GS-TNRT',   '{"form_factor":"4U","max_gpus":8,"max_ram_gb":4096,"storage":"24x NVMe"}'),
  ('Cisco',  'Nexus 9336C-FX2',     '{"ports":"36x 100GbE QSFP28","throughput_tbps":7.2,"latency_us":1}'),
  ('Arista', '7050CX3-32S',         '{"ports":"32x 100GbE","throughput_tbps":6.4,"latency_us":0.9}'),
  ('APC',    'Smart-UPS 3000VA',    '{"capacity_va":3000,"battery_runtime_min":14,"output_w":2700}'),
  ('Eaton',  'UPS 9PX 11000i',      '{"capacity_va":11000,"efficiency_pct":99,"output_w":10000}'),
  ('NetApp', 'AFF A400',            '{"capacity_tb":2800,"throughput_gbps":12,"latency_us":150}'),
  ('Pure Storage','FlashArray//X',  '{"capacity_tb":5000,"read_iops":15000000,"latency_us":100}'),
  ('OpenAI', 'GPT-4o',              '{"context_tokens":128000,"output_tps":100,"latency_ms":300}'),
  ('Meta',   'Llama 3 70B',         '{"params_b":70,"context_tokens":8192,"quantization":"FP16/INT8"}'),
  ('Mistral AI','Mixtral 8x7B',     '{"params_b":47,"context_tokens":32768,"architecture":"MoE"}'),
  ('Pinecone','Serverless',         '{"vectors_max":1e9,"dimensions":1536,"query_latency_ms":10}'),
  ('Weaviate','Cloud Enterprise',   '{"vectors_max":1e9,"modules":["text2vec-openai","generative-openai"]}'),
  ('Redis',  'Redis Stack 7',       '{"data_structures":"Hash,List,Set,Sorted Set,JSON","vector_search":true}'),
  ('Cloudflare','WAF Enterprise',   '{"rules":">10000","ddos_protection":true,"bot_management":true}'),
  ('Kong',   'Kong Gateway 3',      '{"plugins":">100","rate_limiting":true,"oauth2":true}'),
  ('HashiCorp','Terraform 1.8',     '{"providers":">4000","state_backend":"S3/GCS/Azure"}')
) AS m(vendor_name, name, specs)
  ON v.name = m.vendor_name
ON CONFLICT (vendor_id, name) DO NOTHING;
