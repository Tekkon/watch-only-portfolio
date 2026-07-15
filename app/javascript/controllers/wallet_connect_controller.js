import { Controller } from "@hotwired/stimulus"

// Connect-wallet-to-VIEW (no account) — plan §7.1. Uses the injected EIP-1193
// provider (window.ethereum: MetaMask, Rabby, Trust, …). On load, if a wallet
// is ALREADY authorized we redirect to its portfolio by default; otherwise we
// reveal a Connect button that requests accounts on click. No signature, no
// server auth — this is just a shortcut to the public /:address viewer.
export default class extends Controller {
  static targets = ["button", "error", "divider"]

  connect() {
    if (!this.hasProvider) return

    // A wallet exists → offer the button and the "or look up any address" divider.
    this.buttonTarget.classList.remove("hidden")
    if (this.hasDividerTarget) this.dividerTarget.hidden = false

    this.redirectIfAlreadyConnected()
  }

  // Button action: prompt the wallet for access, then redirect to the address.
  async requestConnect() {
    try {
      const accounts = await window.ethereum.request({ method: "eth_requestAccounts" })
      if (accounts && accounts.length > 0) {
        this.redirectTo(accounts[0])
      } else {
        this.showError("No account was returned by your wallet.")
      }
    } catch (error) {
      // 4001 = user rejected the request (EIP-1193).
      const message = error?.code === 4001
        ? "Connection request was rejected."
        : "Couldn't connect to your wallet."
      this.showError(message)
    }
  }

  get hasProvider() {
    return typeof window !== "undefined" && Boolean(window.ethereum)
  }

  // Silent check — eth_accounts returns already-authorized accounts WITHOUT
  // prompting. If one is present, honor "connected wallet shown by default".
  async redirectIfAlreadyConnected() {
    try {
      const accounts = await window.ethereum.request({ method: "eth_accounts" })
      if (accounts && accounts.length > 0) this.redirectTo(accounts[0])
    } catch (_error) {
      // Ignore — the user can still click Connect or use the search box.
    }
  }

  redirectTo(address) {
    // The public viewer route is just /:address.
    window.location.assign(`/${address}`)
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }
}
