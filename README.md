# K2 Insurance — Salesforce Org & Public Assets

K2 Insurance의 Salesforce Org(Production)에 배포되는 메타데이터와, 외부에 공개되는 정적 자산을 함께 관리하는 단일 레포입니다.

- **운영 주체**: K2 Insurance
- **개발/유지보수**: 5S Infusion (MSP 계약 하에 관리)
- **레포 공개 정책**: **Public** — GitHub Pages 정적 자산 호스팅을 위해 공개 상태를 유지합니다. 민감 정보(고객 PII, 매출 raw data, Org credentials 등)는 절대 커밋하지 않습니다.

---

## 디렉토리 맵

| Path | 용도 |
|---|---|
| [force-app/](force-app/) | Salesforce DX 소스 (LWC, Apex, Flow, Layout 등) |
| [manifest/](manifest/) | 배포 manifest (`package.xml`) |
| [config/](config/) | Scratch Org 정의 등 |
| [scripts/](scripts/) | Apex 일회성 스크립트 + 운영 유틸리티 (`verify-pages.sh` 등) |
| [docs/](docs/) | 클라이언트 보고서 및 내부 문서 |
| [email/](email/) | **이메일 템플릿이 참조하는 외부 공개 정적 자산** (로고 등). GitHub Pages로 서빙. 운영 가이드는 [email/README.md](email/README.md) 참고. |
| `Commission Statements/` | 보험사별 커미션 명세 (월별) |

---

## Salesforce DX 기본 명령

```bash
sf project deploy start --manifest manifest/package.xml --target-org <alias>
sf project retrieve start --manifest manifest/package.xml --target-org <alias>
```

추가 참고: [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/), [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm).

---

## GitHub Pages (이메일 자산 CDN)

이 레포는 GitHub Pages를 통해 `email/` 디렉토리의 자산을 HTTPS로 서빙합니다.

- Primary URL 예: `https://archliam.github.io/K2Insurance/email/logo.png`
- Backup CDN (jsDelivr): `https://cdn.jsdelivr.net/gh/ArchLiam/K2Insurance@master/email/<path>`

상세 운영 가이드 및 자산 일람: **[email/README.md](email/README.md)**

---

## License

© K2 Insurance. All rights reserved.

본 레포의 코드와 자산은 K2 Insurance 소유이며, 외부 사용·재배포는 금지됩니다. Salesforce 메타데이터에 포함된 Apex/LWC 등의 소스가 외부에 노출되어 있는 것은 GitHub Pages 호스팅 요건에 따른 기술적 결과일 뿐이며, 사용 라이선스를 부여하는 것은 아닙니다.
