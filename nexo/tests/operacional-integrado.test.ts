import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'
import { beforeAll, beforeEach, afterEach, afterAll, expect, it } from 'vitest'

const read = (p: string) => readFileSync(new URL(p, import.meta.url), 'utf8')
const id = (n: number) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`
let db: PGlite
async function login(n: number) {
  await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub','${id(n)}',false);`)
}
beforeAll(async () => {
  db = new PGlite()
  await db.exec(read('./fixtures/acesso_antes.sql'))
  await db.exec(`
    insert into empresas(id,nome,ativo) values('${id(1)}','A',true),('${id(2)}','B',true);
    insert into perfis(id,nome) values('${id(10)}','ADMIN'),('${id(11)}','EXECUTOR'),('${id(12)}','AUDITOR'),('${id(13)}','GESTOR');
    insert into pessoas(id,empresa_id,nome,ativo) values
      ('${id(101)}','${id(1)}','Admin',true),('${id(102)}','${id(1)}','Executor',true),
      ('${id(103)}','${id(1)}','Conferente',true),('${id(104)}','${id(1)}','Aprovador',true),
      ('${id(105)}','${id(1)}','Auditor',true),('${id(106)}','${id(1)}','Observador',true),
      ('${id(107)}','${id(2)}','Outra empresa',true),('${id(108)}','${id(1)}','Gestor sem setor',true);
    insert into usuarios(id,pessoa_id,perfil_id,ativo) values
      ('${id(201)}','${id(101)}','${id(10)}',true),('${id(202)}','${id(102)}','${id(11)}',true),
      ('${id(203)}','${id(103)}','${id(11)}',true),('${id(204)}','${id(104)}','${id(11)}',true),
      ('${id(205)}','${id(105)}','${id(12)}',true),('${id(206)}','${id(106)}','${id(11)}',true),
      ('${id(207)}','${id(107)}','${id(10)}',true),('${id(208)}','${id(108)}','${id(13)}',true);
    insert into operacoes(id,empresa_id,nome,exige_conferencia,exige_aprovacao,exige_evidencia)
      values('${id(301)}','${id(1)}','Operação',true,true,false);
    insert into execucoes(id,operacao_id,responsavel_id,titulo,status,percentual_conclusao)
      values('${id(401)}','${id(301)}','${id(102)}','Atividade','EM_EXECUCAO',0);
    insert into execucao_participantes(execucao_id,pessoa_id,papel,ativo)
      values('${id(401)}','${id(106)}','OBSERVADOR',true);
  `)
  await db.exec('update operacoes set ativo=true');
  await db.exec(read('../sql/002_acesso_empresa.sql'))
  await db.exec(read('../sql/003_papeis_operacionais.sql'))
  await db.exec(read('../sql/004_operacional_integrado.sql'))
  await db.exec(read('../sql/004_operacional_integrado.sql'))
}, 60000)
beforeEach(async () => { await db.exec('begin;') })
afterEach(async () => { await db.exec('rollback; reset role;') })
afterAll(async () => { await db.close() })

async function painel() { return (await db.query<{v: any}>(`select nexo_painel_operacional(30) v`)).rows[0].v }
it('painel sem amostra não inventa prazo, ciclo ou pontuação', async () => {
 await login(202); const p=await painel(); expect(p.abertas).toBe(1); expect(p.no_prazo).toBeNull(); expect(p.ciclo_horas).toBeNull(); expect(p.equipe).toHaveLength(1); expect(p.equipe[0].pontuacao).toBeNull()
})
it('diretor desliga pontuação no servidor e registra alteração', async () => {
 await login(201); await db.exec("select nexo_configurar_pontuacao('DESATIVADA')"); const p=await painel(); expect(p.pontuacao_visivel).toBe(false); expect(p.equipe.every((x:any)=>x.pontuacao===null)).toBe(true); expect((await db.query('select * from nexo_governanca_historico')).rows).toHaveLength(1)
})
it('equipe não pode mudar configuração nem receber notas privativas da gestão', async () => {
 await login(201); await db.exec("select nexo_configurar_pontuacao('GESTAO')"); await login(202); expect((await painel()).pontuacao_visivel).toBe(false); await expect(db.exec("select nexo_configurar_pontuacao('TODOS')")).rejects.toThrow('diretoria')
})
it('não mistura empresas nem pessoas fora do escopo', async () => {
 await login(207); expect((await painel()).abertas).toBe(0); await login(202); expect((await db.query('select id from pessoas')).rows).toEqual([{id:id(102)}])
})
it('gestor sem setor não enxerga pessoas sem setor; gestor_id permite subordinado', async () => {
 await login(208); expect((await painel()).abertas).toBe(0); await db.exec('reset role'); await db.exec(`update pessoas set gestor_id='${id(108)}' where id='${id(102)}'`); await login(208); expect((await painel()).abertas).toBe(1)
})
it('conversão é atômica e idempotente, com participante e histórico', async () => {
 await login(202); await db.exec(`insert into demandas(id,empresa_id,solicitante_id,responsavel_id,operacao_id,titulo,status,prioridade) values('${id(701)}','${id(1)}','${id(102)}','${id(102)}','${id(301)}','Teste','ABERTA','NORMAL')`)
 const a=(await db.query<{v:string}>(`select nexo_converter_demanda('${id(701)}') v`)).rows[0].v
 const b=(await db.query<{v:string}>(`select nexo_converter_demanda('${id(701)}') v`)).rows[0].v
 expect(a).toBe(b); expect((await db.query(`select * from execucao_participantes where execucao_id='${a}'`)).rows).toHaveLength(1); expect((await db.query(`select * from demanda_status_historico where demanda_id='${id(701)}'`)).rows).toHaveLength(2)
})
it('não cria execuções para responsável de outra empresa', async () => {
 await login(201); await expect(db.exec(`insert into execucoes(id,operacao_id,responsavel_id,status) values('${id(702)}','${id(301)}','${id(107)}','NAO_INICIADA')`)).rejects.toThrow('escopo')
})
it('diretório não expõe e-mail nem credenciais', async () => {
 await login(202); const rows=(await db.query('select * from nexo_diretorio()')).rows; expect(rows.length).toBe(7); expect(Object.keys(rows[0])).toEqual(['id','nome','setor_id'])
})
it('redistribuição preserva auditoria e troca acesso do responsável', async () => {
 await login(201); await db.exec(`select nexo_gerir_atividade('execucoes','${id(401)}','${id(103)}',now()+interval '1 day','Redistribuição')`)
 expect((await db.query('select * from nexo_gestao_historico')).rows).toHaveLength(1)
 await login(202); expect((await db.query('select id from execucoes')).rows).toHaveLength(0)
 await login(203); expect((await db.query('select id from execucoes')).rows).toHaveLength(1)
})
it('executor não altera prazo para manipular pontuação', async () => {
 await login(202); await expect(db.exec(`update execucoes set data_prevista=now()+interval '1 year'`)).rejects.toThrow('gestão')
})
it('demanda acompanha conclusão e reabertura da execução sem perder vínculo', async () => {
 await db.exec('update operacoes set exige_conferencia=false,exige_aprovacao=false'); await login(202)
 await db.exec(`insert into demandas(id,empresa_id,solicitante_id,responsavel_id,operacao_id,titulo,status) values('${id(701)}','${id(1)}','${id(102)}','${id(102)}','${id(301)}','Teste','ABERTA')`)
 const x=(await db.query<{v:string}>(`select nexo_converter_demanda('${id(701)}') v`)).rows[0].v
 await db.exec(`select nexo_concluir_execucao('${x}')`)
 expect((await db.query('select status from demandas')).rows).toEqual([{status:'CONCLUIDA'}])
 await login(201); await db.exec(`select nexo_gerir_atividade('execucoes','${x}','${id(102)}',null,'Correção necessária',null,true)`)
 expect((await db.query('select status,data_conclusao from demandas')).rows).toEqual([{status:'EM_EXECUCAO',data_conclusao:null}])
})
it('conversão falha sem deixar execução ou histórico parcial', async () => {
 await login(202); await db.exec(`insert into demandas(id,empresa_id,solicitante_id,responsavel_id,titulo,status) values('${id(701)}','${id(1)}','${id(102)}','${id(102)}','Teste','ABERTA'); savepoint conversao;`)
 await expect(db.exec(`select nexo_converter_demanda('${id(701)}')`)).rejects.toThrow('Defina operação')
 await db.exec('rollback to savepoint conversao'); expect((await db.query('select id from execucoes')).rows).toHaveLength(1)
})
it('indicadores usam entregas com prazo conhecido e duração válida', async () => {
 await db.exec(`alter table execucoes disable trigger all; update execucoes set status='CONCLUIDA',data_conclusao=now()-interval '1 hour',data_inicio=now()-interval '3 hours',data_prevista=now(),sla_minutos=180; alter table execucoes enable trigger all;`)
 await login(202); const p=await painel(); expect(p.entregues).toBe(1); expect(p.no_prazo).toBe(100); expect(p.sla).toBe(100); expect(p.ciclo_horas).toBe(2); expect(p.equipe[0].pontuacao).toBe(100)
})
it('anônimo não recebe painel nem configurações', async () => {
 await db.exec('set role anon'); await expect(db.exec('select nexo_painel_operacional(30)')).rejects.toThrow('permission denied')
})
it('reversão preserva históricos e restaura regras anteriores', async () => {
 await login(201); await db.exec("select nexo_configurar_pontuacao('GESTAO'); commit; reset role;")
 await db.exec(read('../sql/004_reverter_operacional_integrado.sql'))
 expect((await db.query('select * from nexo_governanca_historico')).rows).toHaveLength(1)
 await login(202); expect((await db.query('select id from execucoes')).rows).toHaveLength(1)
 await expect(db.exec('select nexo_painel_operacional(30)')).rejects.toThrow('permission denied')
})
