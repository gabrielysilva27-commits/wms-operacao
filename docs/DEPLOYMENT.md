# Implantação — 15/10/2026

- Organização: WMS; conexão selecionada: wms. Plano informado pelo Supabase: free.
- Projeto exclusivo: WMS-OPERACAO; ref `pzdkndhyivfqpkbcrsld`; região `sa-east-1`.
- Cinco migrações aplicadas; arquivos locais alinhados às versões registradas no servidor.
- 27 tabelas em public, todas com RLS. Bucket wms-evidence privado, limite de arquivo 50 MiB.
- Armazém inicial: Duque de Caxias, America/Sao_Paulo.
- RPCs públicas são SECURITY INVOKER; as implementações privilegiadas ficam no esquema interno não exposto, com verificações de usuário/função/armazém. Rotinas de agentes não têm grant a authenticated.
- Advisors de segurança: nenhum alerta após a revisão. Performance: somente índices ainda sem uso, esperado em banco recém-criado; nenhum FK sem índice cobrindo o relacionamento.
- Verificação HTTP real com publishable key: consulta anônima de paletes retorna lista vazia; execução anônima do sorteio retorna HTTP 401 / permission denied.
- 12 testes locais PostgreSQL/PGlite passaram incluindo a quinta migração. Auth/Storage reais e cenários autenticados completos ainda dependem do primeiro usuário.
- Primeiro administrador: pendente de definição do e-mail e provisionamento seguro. Não há usuário fictício no banco. A demonstração fica isolada na memória do navegador.
- Frontend contém apenas URL e chave publishable do projeto WMS. Nenhum segredo de serviço é enviado ao cliente.
- Nenhum recurso da conta anterior foi modificado. Promax continua desativado.

A interface e as migrações são a fundação inicial, não um piloto operacional homologado. Ver README e SPECIFICATION para funcionalidades ainda em implementação.

## Retomada em 09/11/2026

- Projeto Supabase reativado e confirmado ACTIVE_HEALTHY. Consulta real confirmou 27 tabelas com RLS, bucket privado e nenhum usuário/vínculo ainda cadastrado.
- PWA: ícones PNG 180/192/512, metadados Apple, manifest com identidade/escopo e abertura em Minha operação. Botão de instalação usa prompt do navegador quando disponível e instrução manual em outros casos.
- Cache contém somente shell estático; navegação offline encontra shell. Respostas da API e evidências não são guardadas no Cache Storage. Atualização não recarrega uma operação em andamento.
- QA de navegador: orientação Instalar app e navegação Minha operação funcionaram na prévia local. Instalação real em Android/iPhone e operação autenticada seguem pendentes.
- Hospedagem externa Cloudflare segue sem confirmação: sessão disponível abriu em login.
