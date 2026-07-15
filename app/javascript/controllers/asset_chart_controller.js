import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js"

// Renders the per-asset allocation pie chart from Dashboard::AssetAllocation
// JSON ({ labels, values, percentages }) supplied via the data-value.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    const { labels = [], values = [], percentages = [] } = this.dataValue

    this.chart = new Chart(this.canvasTarget, {
      type: "doughnut",
      data: {
        labels,
        datasets: [{ data: values, borderWidth: 1 }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const pct = percentages[ctx.dataIndex]
                const usd = ctx.parsed.toLocaleString("en-US", {
                  style: "currency",
                  currency: "USD"
                })
                return `${ctx.label}: ${usd}${pct != null ? ` (${pct}%)` : ""}`
              }
            }
          }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
