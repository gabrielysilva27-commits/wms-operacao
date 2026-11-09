# Ativação no novo Supabase

1. Conectar a nova conta e selecionar explicitamente a organização. Consultar e informar custo antes de provisionar. NÃO usar nem restaurar projetos existentes da conta anterior.
2. Criar projeto exclusivo WMS em região adequada à operação no Brasil, avaliando disponibilidade/custo. Registrar project ref no controle de implantação, sem credenciais no Git.
3. Aplicar migrações em ordem 001–004 no projeto vazio. Não executar sobre banco com aplicações preexistentes. Conferir extensão/RLS/grants, constraints, funções e bucket privado.
4. Configurar Auth: cadastro público desativado, URLs autorizadas, política de senha, recuperação e validade de sessão. Criar primeira identidade por canal administrativo seguro. Nunca enviar senha pelo chat nem usar uma chave service_role no cliente.
5. Criar armazém e primeiro vínculo admin via SQL confiável. Depois usar `set_membership` para vínculos de usuários já existentes em Auth. Não há autoinscrição. Definir José como `recorder`.
6. Configurar somente URL do novo projeto e publishable key no `dist/config.js`, republicar. Service credentials ficam exclusivamente no futuro backend/agente, nunca no frontend.
7. Executar advisors e testes reais com admin, ajudante, conferente, registro visual e usuário sem vínculo. Validar negação anônima e isolamento; upload/download privados, reenvio após falha e revogação de vínculo.
8. Importar CSVs em área de preparação e validar unidades, pesos, lastro, camadas, dimensões, duplicatas e endereços antes de inserir. Não inventar parâmetros faltantes. Não importar resultados fictícios da demonstração.
9. Homologar prioridade, janela de equilíbrio, esforço e bloqueios; duas sessões simultâneas no mesmo palete; presença alterada durante atribuição; layout trocado no turno; sessão expirada e palm sem rede.
10. Configurar acesso da equipe ao app e testar instalação PWA em dispositivos reais. Publicação owner-private é exclusivamente revisão da proprietária. Medir latência e volume; criar índices adicionais a partir de consultas reais.

## Segurança e limites conhecidos

Senhas Auth não são salvas no frontend. Tokens ficam apenas em memória e são renovados enquanto a aplicação está aberta; ao recarregar, exige login novamente. Shell estático pode ser usado offline. Comandos operacionais não são confirmados offline: mostram falha e exigem nova tentativa conectada; apenas mídia usa fila durável. Não afirmar que uma tarefa foi confirmada no servidor sem resposta.

PGlite valida SQL/PostgreSQL e políticas com substitutos mínimos de Auth/Storage. Não valida o serviço Supabase Auth, APIs Storage, PostgREST, rede dos palms, gateway privado ou concorrência entre processos. Nunca chamar isso de produção homologada antes dos testes reais.

Promax fica desativado, inclusive na rotina de claim. Para implementação futura: observação supervisionada das telas reais, mapeamento de campos, reconciliação de Carga Montada/Carregamento, validação de placa/mapa/ativos, confirmação externa e contingência manual.

Changelog consultado em 15/10/2026: desativação de subconjunto de cifras TLS 1.2 prevista para 10/11/2026. Frontend usa fetch HTTPS moderno; verificar suporte do Windows/agente ao implementar.
