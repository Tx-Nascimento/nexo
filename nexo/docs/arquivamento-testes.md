# Arquivar registros de teste sem apagar o histórico

Instalar `sql/006_arquivar_testes.sql` no SQL Editor como postgres, após 005. O arquivo genérico não contém IDs de produção e não arquiva registros sozinho. A entrega ao responsável contém a mesma instalação mais a lista exata do diagnóstico, em uma transação.

`nexo_arquivar_testes(jsonb)` recebe a lista do diagnóstico (entidade, id, empresa_id, nome). Só o dono do banco executa; PUBLIC, anon e authenticated não têm permissão. Valida existência, empresa única, nomes inalterados, marcador explícito [TESTE]/[TESTE OPERACIONAL]/[DEMO] e IDs sem duplicidade. Uma palavra no título sozinha não seleciona um registro: somente a lista fornecida é tratada.

Antes de arquivar operações e execuções, verifica se há execuções ou demandas vinculadas fora da lista. Nesse caso aborta, sem arquivar nada. Não inclui automaticamente outros cadastros. O bloqueio transacional impede novas vinculações concorrentes durante a validação.

O registro original permanece na tabela de origem, com snapshot em `nexo_arquivo_testes`, inacessível à API. As políticas restritivas e funções de escopo retiram execuções/demandas das telas, consultas e KPIs. O catálogo de filtros exclui operações arquivadas. Operações, documentos e recorrências das operações arquivadas ficam inativos; o estado anterior é preservado. Pessoas, setores, processos, arquivos Storage, evidências e históricos não são apagados.

Reaplicar a mesma lista é idempotente e preserva o primeiro snapshot. Se houver erro, enviar a mensagem antes de tentar modificar a lista. O script não desativa RLS nem triggers.

## Restauração

Como postgres no SQL Editor:

```sql
SELECT public.nexo_restaurar_testes('UUID_DA_EMPRESA'::uuid);
```

Restaura a visibilidade dos registros arquivados pela função e os flags de atividade anteriores dos cadastros/recorrências. Preserva as regras novas: passam a não filtrar os registros restaurados. A API não pode chamar a restauração. Não sobrescreve títulos, conteúdo, status ou histórico operacional.

## Validação

Testes locais em PostgreSQL/PGlite: isolamento do arquivo, exclusão dos KPIs/catálogos, recusa de vínculos fora da lista, empresa divergente, chamada por ADMIN da aplicação, idempotência, restauração e preservação do conteúdo. Não executado no Supabase real pelo agente; a execução cabe ao responsável do banco.
