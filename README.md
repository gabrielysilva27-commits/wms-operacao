# WMS Operação

Aplicativo próprio de gestão e operação do armazém. Interface desktop e PWA para palms/celulares, Supabase exclusivo para banco, autenticação e registro visual.

## Estado

Fundação em desenvolvimento e demonstração identificada. Ainda não é um sistema homologado para operação real. Primeiro administrador e importação de cadastros seguem pendentes. Promax permanece desativado.

## Desenvolvimento

Node.js 22 ou superior. `npm ci`, `npm run build`, `npm test`.

## Cloudflare Workers

Conecte este repositório a um novo Worker **wms-operacao**, branch **main**.

- Build command: `npm run build`
- Deploy command: `npx wrangler deploy`
- Root directory: raiz do repositório (deixe vazio ou `/` conforme a tela).
- Arquivos estáticos: `dist/`, declarados em `wrangler.jsonc`.

Esta implantação é independente dos Workers e bancos de Painel Armazém, Workstation e Lead Gestão.

`dist/config.js` contém somente URL e chave publicável do Supabase exclusivo. Senhas, service_role e outros segredos devem ficar fora do código. O acesso a dados exige usuário ativo e políticas de autorização no banco.

## Fundação

Usuários/funções/habilidades, presença, esforço em segundos padrão, Matriz de Priorização antes do sorteio, mapas/paletes/itens, conferência assíncrona, endereçamento versionado, fila de mídia e contratos de jobs para agentes futuros. Consulte `docs/SPECIFICATION.md`.
