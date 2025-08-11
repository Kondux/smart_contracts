### Security Policy for Kondux Smart Contracts Repository

Kondux aims to build trustworthy and secure smart‑contract infrastructure for NFT minting, staking and tokenomics. Because smart contracts are immutable once deployed, **security must be a first‑class concern**. The Ethereum Smart Contract Best Practices guide notes that non‑trivial contracts will have errors and recommends that code is designed to *“respond to bugs and vulnerabilities gracefully”* by allowing pausing, limiting funds at risk and supporting upgrades. This policy explains how to responsibly disclose security issues, outlines how the Kondux team handles vulnerabilities and summarises the project’s security expectations.

#### Supported versions & maintenance

* The **`main`** branch of this repository is the reference implementation of the Kondux smart contracts.
* Releases are versioned via Git tags and deployments.
* The team maintains the current released version; older deployments may not receive security fixes.
* Users should always verify that they interact with **official contract addresses** published in the Kondux documentation and avoid outdated forks.

#### Reporting a vulnerability

1. **Private disclosure** – Use the “Report a vulnerability” button on the repository’s Security tab to open a private security advisory. Alternatively, email the Kondux security team at **[security@kondux.io](mailto:security@kondux.io)** (PGP key available in this repository) with the details. Do **not** report vulnerabilities via public issues or social media.
2. **Include sufficient detail** – Provide a clear description of the issue, the conditions required to reproduce it, and the potential impact. If possible, include PoC code, transaction traces or failing tests.
3. **Coordinate on a fix** – We will acknowledge receipt within **7 days**. According to GitHub’s best practices, maintainers should acknowledge reports quickly and involve the reporter in verifying the fix. We aim to resolve critical vulnerabilities within **90 days** and will work with you on an appropriate disclosure timeline.
4. **Credit and recognition** – We will publicly acknowledge the reporter after the fix is released unless anonymity is requested. Please note that there is currently **no guaranteed monetary bounty**; however, significant findings may be rewarded at the discretion of the Kondux team.

##### Responsible disclosure expectations

Vulnerability reporters are asked to adhere to the following guidelines, aligned with industry norms:

* **Do not disclose publicly** until an official fix is available. Premature disclosure may put user funds at risk.
* Avoid testing with real funds or causing downtime. Use local test networks or public testnets.
* Do not attempt to access, modify or destroy data that does not belong to you. Penetration tests must be purely observational.
* Never exploit a vulnerability beyond what is necessary to prove its existence.
* Understand that if no official bug‑bounty programme exists, there is no expectation of payment.

#### Vulnerability severity levels

To prioritise remediation and provide consistent communication, Kondux classifies vulnerabilities as follows:

| Category     | Typical impact                                                                                                                            | Examples                                                                                                                            |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Critical** | Could cause immediate loss or permanent lock‑up of user or contract funds; allows an attacker to take full control of the contract.       | Unlimited re‑entrancy leading to draining of staking pools; integer overflows enabling minting of arbitrary tokens.                 |
| **High**     | Could allow significant financial loss or permanent denial of service but requires specific conditions; might allow privilege escalation. | Missing access control leading to unauthorized minting or pausing; unprotected external call with state change enabling reentrancy. |
| **Medium**   | Has moderate impact, such as blocking functions or leaking limited data; requires user interaction or unlikely circumstances.             | Failing to handle external call errors or gas‑related Denial‑of‑Service in the reward calculation.                                  |
| **Low**      | Minor issues that do not directly impact contract integrity or funds; often related to coding style or gas inefficiency.                  | Unused variables, minor front‑end vulnerabilities or documentation errors.                                                          |

When evaluating bug bounty rewards, the Safe Haven guidelines recommend determining tiers of rewards and letting a group of judges decide based on the severity and impact. Kondux follows a similar approach: higher‑severity issues may receive higher recognition, and exceptionally severe vulnerabilities may qualify for additional rewards (subject to available budget).

#### Scope of this policy

This policy covers smart contracts in the `contracts/` directory of this repository and their associated deployment scripts. Vulnerabilities in the Kondux front‑end, documentation site, social channels or third‑party dependencies are **out‑of‑scope**, unless they directly affect the integrity of the smart contracts. Exclusions include:

* Social engineering, phishing or physical attacks against Kondux staff or contributors.
* Denial‑of‑service attacks that merely cause high gas costs without threatening funds.
* Automated scanning reports without a demonstrable security impact.

#### Secure development & best practices

##### Limit trust and use well‑vetted libraries

* **Treat external calls as potential security risks** – Calls to untrusted contracts may execute malicious code.
* **Avoid state changes after external calls** – Make state updates before calling external contracts.
* **Prefer `.call()` over `.transfer()` or `.send()`** – Using `.call()` and checking the return value is recommended.
* **Handle errors in low‑level calls** – Always check the returned success flag.
* **Use pull over push payments** – Isolate each external payment into a separate withdrawal action.
* **Rely on well‑established libraries** – The Smart Contract Security Field Guide suggests using reliable libraries like OpenZeppelin.

##### Principle of least privilege & access control

* Grant only the permissions necessary to perform a task.
* Use role‑based access control to separate responsibilities.
* Implement circuit breakers and pause functionality.

##### Input validation and proactive checks

* Validate inputs early and thoroughly.
* Apply validation inside internal functions, not just externally.
* Consider purposeful delays (“speed bumps”) for high‑impact administrative actions.

##### Dependencies and version management

* Keep dependencies updated and review third‑party code.
* Use static and dynamic analysis tools and remove secrets from source control.

##### Monitoring & auditing

* Use CI pipelines with security linters and analyzers.
* Monitor deployed contracts for unusual activities.
* Commission independent security audits before major releases.

#### Safe use guidelines for end users

* **Verify official contracts** – Use only contract addresses published in the Kondux docs or website.
* **Inspect the code** – Review verified source code on Etherscan; be cautious with unknown contracts.
* **Use secure wallets** – Prefer hardware wallets; never share mnemonics or commit secrets.
* **Test with small amounts first** – Verify behaviour before committing significant funds.
* **Stay informed** – Follow Kondux announcements and update dApps when patched contracts are released.

#### Contact & further information

For questions about this security policy or to request the PGP key, contact **[security@kondux.io](mailto:security@kondux.io)**. We encourage all contributors and users to consult the *Smart Contract Security Field Guide* and *Ethereum Smart Contract Best Practices* for deeper understanding of secure development principles.
