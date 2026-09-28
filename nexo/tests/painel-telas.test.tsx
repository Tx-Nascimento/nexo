// @vitest-environment jsdom
import { act } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
const mock=vi.hoisted(()=>({rpc:vi.fn()}))
vi.mock('../src/lib/supabase',()=>({supabase:{rpc:mock.rpc}}))
import Painel from '../src/components/PainelOperacional'
let root:Root,container:HTMLDivElement
const dados={gerado_em:'2026-09-28T12:00:00Z',inicio:'2026-09-01',modo:'TODOS',pontuacao_visivel:true,abertas:4,atrasadas:1,sem_prazo:1,bloqueadas:1,dependencias:0,entregues:2,amostra_prazo:2,no_prazo:50,retrabalho:0,ciclo_horas:2,demandas_abertas:0,sla:100,idade:[],causas:[],status:[],gargalos:[],fluxo:[],equipe:[],fila:[],decisoes:[]}
beforeEach(()=>{
 Object.assign(globalThis,{IS_REACT_ACT_ENVIRONMENT:true});vi.clearAllMocks()
 mock.rpc.mockImplementation((nome:string)=>Promise.resolve({data:nome==='nexo_filtros_painel'?{setores:[{id:'s1',nome:'Compras'},{id:'s2',nome:'Fiscal'}],operacoes:[{id:'o1',nome:'Compra',setor_id:'s1'}]}:dados,error:null}))
 container=document.createElement('div');root=createRoot(container)
})
afterEach(async()=>{await act(async()=>root.unmount())})
async function render(){await act(async()=>root.render(<Painel usuario={{nome:'Exemplo',perfil:'DIRETORIA',pessoaId:'p1',empresaId:'e1'}}/>))}
async function click(text:string){const b=[...container.querySelectorAll('button')].find(b=>b.textContent===text)!;await act(async()=>b.click())}
async function select(label:string,value:string){const el=container.querySelector<HTMLSelectElement>(`select[aria-label="${label}"]`)!;await act(async()=>{el.value=value;el.dispatchEvent(new Event('change',{bubbles:true}))})}
it('uma análise por vez: resumo não empilha fila, equipe e configuração',async()=>{
 await render();expect(container.textContent).not.toContain('Fila de atenção');expect(container.textContent).not.toContain('Governança da pontuação')
 await click('Atendimento');expect(container.textContent).toContain('Tempo de ciclo');expect(container.textContent).not.toContain('O que precisa de atenção?')
 await click('Prioridades');expect(container.textContent).toContain('Fila de atenção');expect(container.textContent).not.toContain('Tempo de ciclo')
})
it('filtro envia o recorte ao servidor e troca de setor limpa a operação',async()=>{
 await render();await select('Filtrar setor','s1');await select('Filtrar operação','o1');expect(mock.rpc).toHaveBeenLastCalledWith('nexo_painel_filtrado',{p_dias:30,p_setor:'s1',p_operacao:'o1'})
 await select('Filtrar setor','s2');expect(mock.rpc).toHaveBeenLastCalledWith('nexo_painel_filtrado',{p_dias:30,p_setor:'s2',p_operacao:null})
})
it('simulação avança e reinicia sem escrever no banco',async()=>{
 await render();await click('Simulações');const antes=mock.rpc.mock.calls.length
 await click('Simular etapa concluída →');expect(container.textContent).toContain('Etapa simulada: em execucao');await click('Reiniciar simulação');expect(container.textContent).toContain('Etapa simulada: aberta');expect(mock.rpc).toHaveBeenCalledTimes(antes)
})
