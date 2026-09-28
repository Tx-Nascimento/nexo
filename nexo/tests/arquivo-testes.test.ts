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
  await db.exec(read('../sql/005_painel_com_filtros.sql'))
  await db.exec(read('../sql/006_arquivar_testes.sql'))
  await db.exec(read('../sql/006_arquivar_testes.sql'))
}, 60000)
beforeEach(async () => { await db.exec('begin;') })
afterEach(async () => { await db.exec('rollback; reset role;') })
afterAll(async () => { await db.close() })

async function lista(incluirExecucao=true) {
 await db.exec(`update operacoes set nome='[DEMO] Operação' where id='${id(301)}'; alter table execucoes disable trigger all; update execucoes set titulo='[TESTE] Execução' where id='${id(401)}'; alter table execucoes enable trigger all;`)
 return JSON.stringify([{entidade:'operacoes',id:id(301),empresa_id:id(1),nome:'[DEMO] Operação'},...(incluirExecucao?[{entidade:'execucoes',id:id(401),empresa_id:id(1),nome:'[TESTE] Execução'}]:[])])
}
async function arquivar(json:string){return db.query('select nexo_arquivar_testes($1::jsonb) v',[json])}
it('arquiva sem excluir e remove testes do painel e catálogo',async()=>{
 const l=await lista(); await arquivar(l); expect((await db.query('select * from execucoes')).rows).toHaveLength(1); expect((await db.query('select * from nexo_arquivo_testes')).rows).toHaveLength(2)
 await login(201); expect((await db.query('select * from execucoes')).rows).toHaveLength(0); expect((await db.query<{v:any}>('select nexo_painel_filtrado(30) v')).rows[0].v.abertas).toBe(0); expect((await db.query<{v:any}>('select nexo_filtros_painel() v')).rows[0].v.operacoes).toHaveLength(0)
})
it('preserva atividade não incluída e aborta operação com vínculo real',async()=>{
 const l=await lista(false); await db.exec('savepoint limpar'); await expect(arquivar(l)).rejects.toThrow('fora da lista'); await db.exec('rollback to savepoint limpar'); expect((await db.query('select * from nexo_arquivo_testes')).rows).toHaveLength(0); expect((await db.query('select ativo from operacoes')).rows[0].ativo).toBe(true)
})
it('recusa empresa e nome divergentes',async()=>{
 const l=JSON.parse(await lista()); l[0].empresa_id=id(2); l[1].empresa_id=id(2); await expect(arquivar(JSON.stringify(l))).rejects.toThrow('Empresa divergente')
})
it('não executa limpeza pela API mesmo como ADMIN',async()=>{
 const l=await lista(); await login(201); await expect(arquivar(l)).rejects.toThrow('permission denied')
})
it('reaplicação preserva snapshot inicial e restauração repõe visibilidade',async()=>{
 const l=await lista(); await arquivar(l); await arquivar(l); expect((await db.query<{original:any}>("select original from nexo_arquivo_testes where entidade='operacoes'")).rows[0].original.ativo).toBe(true)
 await db.query('select nexo_restaurar_testes($1)',[id(1)]); await login(202); expect((await db.query('select * from execucoes')).rows).toHaveLength(1)
})
it('demanda e documento arquivados saem da consulta sem apagar conteúdo',async()=>{
 await db.exec(`insert into documentos(id,empresa_id,titulo,ativo) values('${id(910)}','${id(1)}','[DEMO] Documento',true)`)
 await login(201);await db.exec(`insert into demandas(id,empresa_id,solicitante_id,titulo,status) values('${id(911)}','${id(1)}','${id(101)}','[DEMO] Demanda','ABERTA')`);await db.exec('reset role')
 await arquivar(JSON.stringify([{entidade:'documentos',id:id(910),empresa_id:id(1),nome:'[DEMO] Documento'},{entidade:'demandas',id:id(911),empresa_id:id(1),nome:'[DEMO] Demanda'}]));await login(201)
 expect((await db.query('select * from demandas')).rows).toHaveLength(0);expect((await db.query('select * from documentos')).rows).toHaveLength(0); expect((await db.query<{v:any}>('select nexo_painel_filtrado(30) v')).rows[0].v.demandas_abertas).toBe(0)
})
