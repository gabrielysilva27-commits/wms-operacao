# Especificação consolidada e decisões da fundação

Fonte principal: pedido de 15/10/2026 e decisões recuperadas da conversa “Iniciar projeto WMS”. Não se presume que detalhes ausentes dos trechos recuperados foram aprovados.

## Fluxo operacional

Gestão por mapa; rastreabilidade por palete e item. Matriz de Priorização precede o sorteio. Maior valor de prioridade significa sair primeiro nesta implementação; o cálculo/importação dos critérios da Matriz precisa ser conectado na próxima etapa. Empate: programação, criação e identificador estável. Nunca escolher mapa menos prioritário só por falta de pessoa habilitada no primeiro: retornar espera explícita ao supervisor.

Sorteio exige vínculo ativo, presença disponível, habilidade válida, função ajudante/empilhador e ausência de atribuição ativa. José tem função `recorder`, dedicada a registro visual e excluída do sorteio. Faixa inicial: menor esforço acumulado na data operacional do armazém + 600 segundos. É parâmetro inicial, não uma constante operacional homologada. O sorteio ocorre no banco, é auditado com candidatos/esforços, prioridade/versão e entropia. O pedido tem chave idempotente. Lock transacional por armazém e índices únicos evitam dupla atribuição.

Esforço padrão = base + caixas × segundos/caixa + distância × segundos/metro. Modelo versionado e snapshot na atribuição. Histórico de duração desconta pausas/bloqueios. Proposta de calibração usa mediana com ao menos 30 observações completas sem divergência aberta e exige revisão humana antes de nova versão.

Conferência registra divergência independente do estado físico. Não devolve palete para correção, não trava trabalho futuro. Próprio conferente pode corrigir depois. Concluir montagem leva a staging, mantém pendências e libera próxima tarefa. A futura liberação de carregamento deve ter validações específicas de segurança física/capacidade; isso não pode virar bloqueio global de tarefas. Não exigir QR, etiquetas diárias ou impressão. Empilhador deve reconhecer posição de staging + veículo/foto sem descer da máquina; fluxo de carga física ainda será implementado.

## Entidades

Armazéns e vínculos usuário/função; habilidades e qualificações válidas; presença histórica por turno; produtos e versões de paletização (lastro, camadas, peso, volume); tipos de veículos, veículos e dimensões/capacidades por baia; layouts e endereços versionados por zona; produtos/endereço; cargas, mapas, paletes e itens; modelos de esforço, atribuições, sorteios, observações; pendências; metadados de mídia; jobs/tentativas; eventos e auditoria.

FKs compostas impedem ligações entre armazéns. RLS de leitura exige vínculo ativo. Escrita de cadastros exige gestor; operação usa RPC com autorização. Usuário não edita a própria função. Admin pode gerenciar vínculos; criação da identidade Auth será feita exclusivamente por backend administrativo. Primeiro admin é provisionado por SQL confiável. Modelos de esforço/paletização são imutáveis; layout publicado só pode ser aposentado, nunca reescrito.

## Mídia

Binário no armazenamento de objetos privado; banco guarda metadados. Fila IndexedDB independente do trabalho. Busca/listagem deve operar metadados, com URLs temporárias sob demanda; thumbnails são próxima etapa. Esta UI lista os 200 registros mais recentes de cada tabela; paginação/busca servidor são pendências antes da produção. Fotos/vídeos de demonstração permanecem no dispositivo. Não existe integração com grupo WhatsApp nesta entrega.

## Agentes

Romaneio, Cora, OCP e Promax têm identificador de adaptador, payload versionado, idempotência, estados e histórico de tentativas. Nenhum deles é executado nesta fundação. Futuro agente Windows no notebook do supervisor da bancada. Promax precisa mapa, placa, ativos de giro e evidência de resultado; operações 03.11.20 Carga Montada e Carregamento. Nenhuma interação com Promax foi implementada.

Claim usa lease/token e SKIP LOCKED. Resultado incerto/lease vencida exige revisão manual; falha transitória confirmada pode repetir com backoff. Jobs desativados não são consumidos. O habilitador de agentes deverá ser implementado apenas ao conectar cada adaptador. Logs devem chegar sanitizados; nunca registrar senha, token, sessão ou dados desnecessários.

## Pendências de ativação e homologação

Novo Supabase, aplicação das migrações, advisors, ensaio de RLS/storage reais; importação revisada dos CSVs Itens, Endereços, veículos e Estoque-consolidado; editores de cadastros e administração; motor de paletização por capacidade/baia e validação física; fluxo de separação item a item e carga física; busca paginada e histórico visual; benchmark concorrente, palms reais, quedas de rede e reconciliação; validação do acesso da equipe fora da publicação privada.
