const data = JSON.parse(require("fs").readFileSync(0, "utf8"));

const out = {
  cwd: data.workspace?.current_dir || data.cwd || "",
  repo_name: data.workspace?.repo?.name || "",
  model: data.model?.display_name || "unknown",
  effort: data.effort?.level || "",
  ctx_used: data.context_window?.used_percentage ?? "",
  five_used: data.rate_limits?.five_hour?.used_percentage ?? "",
  week_used: data.rate_limits?.seven_day?.used_percentage ?? "",
  cost: data.cost?.total_cost_usd ?? 0,
};

for (const [k, v] of Object.entries(out)) {
  const s = String(v).replace(/"/g, '\\"');
  console.log(`${k}="${s}"`);
}
