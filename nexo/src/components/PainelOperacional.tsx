import { GraficoFluxo, GraficoEtapas } from './GraficosOperacionais'
import SimulacoesOperacionais from './SimulacoesOperacionais'
import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario, Pagina } from '../types'
import './PainelOperacional.css'

type Barra = { nome: string; valor: number; entradas?: number; atrasadas?: number }
type Painel = {
  gerado_em: string; inicio: string; modo: string; pontuacao_visivel: boolean
  abertas: number; atrasadas: number; sem_prazo: number; bloqueadas: number; dependencias: number
  entregues: number; amostra_prazo: number; no_prazo: number | null; retrabalho: number | null; ciclo_horas: number | null; demandas_abertas: number
  sla: number | null; idade: Barra[]; causas: Barra[]; status: Barra[]; gargalos: Barra[]; fluxo: Barra[]
  equipe: { id: string; nome: string; abertas: number; atrasadas: number; entregues: number; amostra: number; pontuacao: number | null }[]
  fila: { id: string; titulo: string; operacao: string; status: string; data_prevista: string | null; bloqueada: boolean; dependente: boolean }[]
  decisoes: { execucao_id: string; titulo: string; etapa: string }[]
}
type Props = { usuario: DadosUsuario; navegar?: (pagina: Pagina) => void; abrirExecucao?: (id: string) => void; foco?: 'painel' | 'equipe' }
const nomeStatus = (s: string) => s.toLowerCase().replaceAll('_', ' ')
const numero = (n: number | null, sufixo = '') => n === null ? 'Sem amostra' : `${n.toLocaleString('pt-BR')}${sufixo}`

function Barras({ titulo, dados, fluxo = false }: { titulo: string; dados: Barra[]; fluxo?: boolean }) {
  const max = Math.max(1, ...dados.flatMap(d => [d.valor, d.entradas || 0]))
  return <section className="op-card"><h2>{titulo}</h2>{fluxo && <p className="op-caption">Entradas em azul · conclusões em verde · dias UTC</p>}
    {!dados.length ? <p>Nenhum registro no escopo.</p> : <div className={`op-bars ${fluxo ? 'op-flow' : ''}`} role="img" aria-label={`${titulo}. ${dados.map(d => `${nomeStatus(d.nome)}: ${d.valor}${fluxo ? ` concluídas, ${d.entradas} entradas` : ''}`).join('; ')}`}>
      {dados.map((d, i) => <div className="op-bar-row" key={`${d.nome}-${i}`}><span>{nomeStatus(d.nome)}</span><div className="op-tracks">{fluxo && <div className="op-track"><i className="op-entry" style={{ width: `${100 * (d.entradas || 0) / max}%` }} /></div>}<div className="op-track"><i style={{ width: `${100 * d.valor / max}%` }} /></div></div><b>{fluxo ? `${d.entradas} / ` : ''}{d.valor}</b></div>)}
    </div>}</section>
}

type Aba = 'resumo' | 'atendimento' | 'gargalos' | 'fila' | 'equipe' | 'simulacoes' | 'configuracao'
type Catalogo = { setores: { id: string; nome: string }[]; operacoes: { id: string; nome: string; setor_id: string | null }[] }
const abas: [Aba, string][] = [['resumo','Resumo'],['atendimento','Atendimento'],['gargalos','Gargalos'],['fila','Prioridades'],['equipe','Equipe'],['simulacoes','Simulações']]
export default function PainelOperacional({ usuario, navegar, abrirExecucao, foco = 'painel' }: Props) {
  const [dias, setDias] = useState(30)
  const [setor, setSetor] = useState('')
  const [operacao, setOperacao] = useState('')
  const [aba, setAba] = useState<Aba>(foco === 'equipe' ? 'equipe' : 'resumo')
  const [catalogo, setCatalogo] = useState<Catalogo>({ setores: [], operacoes: [] })
  const [painel, setPainel] = useState<Painel | null>(null)
  const [erro, setErro] = useState('')
  const [erroCatalogo, setErroCatalogo] = useState('')
  const [revisao, setRevisao] = useState(0)
  const [salvando, setSalvando] = useState(false)
  const [filtro, setFiltro] = useState('TODAS')
  const [busca, setBusca] = useState('')
  const diretor = ['ADMIN', 'DIRETORIA'].includes(usuario.perfil)
  const gestor = ['LIDER', 'GESTOR', 'GERENTE'].includes(usuario.perfil)
  const escopo = diretor || usuario.perfil === 'AUDITOR' ? 'Toda a empresa' : gestor ? 'Sua equipe' : 'Suas atividades'
  const simulando = aba === 'simulacoes'
  useEffect(() => {
    let cancelado = false
    setErroCatalogo('')
    supabase.rpc('nexo_filtros_painel').then(({data,error}) => {
      if (cancelado) return
      if (error) { setCatalogo({setores:[],operacoes:[]}); setErroCatalogo('Filtros indisponíveis. Verifique a conexão e a aplicação do SQL 005.') }
      else setCatalogo(data as Catalogo)
    }, () => { if (!cancelado) setErroCatalogo('Falha ao carregar os filtros.') })
    return () => { cancelado = true }
  }, [usuario.pessoaId, usuario.perfil, revisao])
  useEffect(() => {
    let cancelado = false
    setPainel(null); setErro('')
    supabase.rpc('nexo_painel_filtrado', { p_dias: dias, p_setor: setor || null, p_operacao: operacao || null }).then(({ data, error }) => {
      if (cancelado) return
      if (error) setErro('Não foi possível carregar os indicadores. Verifique a conexão e a aplicação do SQL 005 no Supabase.')
      else setPainel(data as Painel)
    }, () => { if (!cancelado) setErro('Falha de conexão. Tente atualizar.') })
    return () => { cancelado = true }
  }, [dias, setor, operacao, revisao, usuario.pessoaId, usuario.perfil])
  async function configurar(modo: string) {
    setSalvando(true); setErro('')
    try {
      const { error } = await supabase.rpc('nexo_configurar_pontuacao', { p_modo: modo })
      if (error) throw error
      setRevisao(r => r + 1)
    } catch { setErro('Não foi possível salvar a configuração.') }
    finally { setSalvando(false) }
  }
  const fila = painel?.fila.filter(e => (filtro === 'TODAS' || (filtro === 'ATRASADAS' ? e.data_prevista && new Date(e.data_prevista) < new Date(painel.gerado_em) : filtro === 'BLOQUEADAS' ? e.bloqueada : e.dependente)) && `${e.titulo} ${e.operacao}`.toLocaleLowerCase('pt-BR').includes(busca.toLocaleLowerCase('pt-BR'))) || []
  const indicadores = (items: [string, number | string, string][]) => <div className="op-kpis op-kpis-compact">{items.map(([t,v,d]) => <section key={t} className={`op-kpi ${t === 'Atrasadas' ? 'op-kpi-alert' : t === 'Entregues' ? 'op-kpi-success' : ''}`}><span>{t}</span><strong>{v}</strong><small>{d}</small></section>)}</div>
  return <div className="op-panel">
    <header className="op-header"><div><p className="op-eyebrow">NEXO / {escopo}</p><h1>{foco === 'equipe' ? 'Equipe' : diretor ? 'Visão executiva' : gestor ? 'Gestão da equipe' : 'Minha operação'}</h1><p>Escolha o recorte e veja uma análise por vez.</p></div>{navegar && <button onClick={() => navegar('demandas')}>Abrir demandas →</button>}</header>
    <nav className="op-view-tabs" aria-label="Telas de indicadores">{[...abas, ...(diretor ? [['configuracao','Configuração'] as [Aba,string]] : [])].map(([id,nome]) => <button key={id} aria-pressed={aba === id} onClick={() => setAba(id)}>{nome}</button>)}</nav>
    {!simulando && <div className="op-filter-strip"><label>Setor<select aria-label="Filtrar setor" value={setor} onChange={e => { setSetor(e.target.value); setOperacao('') }}><option value="">Todos no meu escopo</option>{catalogo.setores.map(s => <option key={s.id} value={s.id}>{s.nome}</option>)}</select></label><label>Operação<select aria-label="Filtrar operação" value={operacao} onChange={e => setOperacao(e.target.value)}><option value="">Todas no meu escopo</option>{catalogo.operacoes.filter(o => !setor || o.setor_id === setor).map(o => <option key={o.id} value={o.id}>{o.nome}</option>)}</select></label><label>Período<select aria-label="Período de entregas" value={dias} onChange={e => setDias(Number(e.target.value))}><option value={7}>Últimos 7 dias</option><option value={30}>Últimos 30 dias</option><option value={90}>Últimos 90 dias</option></select></label><button onClick={() => { setSetor(''); setOperacao(''); setDias(30) }}>Limpar filtros</button><button onClick={() => setRevisao(r => r + 1)}>Atualizar</button></div>}
    {simulando ? <SimulacoesOperacionais /> : <>
    {(erro || erroCatalogo) && <p className="op-error" role="alert">{erro || erroCatalogo}</p>}
    {!painel ? !erro && <p role="status">Carregando indicadores do seu escopo…</p> : <>
      <p className="op-caption">{catalogo.setores.find(s => s.id === setor)?.nome || escopo} · {catalogo.operacoes.find(o => o.id === operacao)?.nome || 'Todas as operações'} · Atualizado {new Date(painel.gerado_em).toLocaleString('pt-BR')}. Carteira atual; entregas no período.</p>
      {aba === 'resumo' && <>
        {indicadores([['Carteira aberta',painel.abertas,'Atividades ainda não encerradas'],['Atrasadas',painel.atrasadas,'Prazo vencido'],['Entregues',painel.entregues,'Conclusões no período'],['No prazo',numero(painel.no_prazo,'%'),`${painel.amostra_prazo} entregas com prazo`]])}
        <div className="op-grid"><GraficoFluxo dados={painel.fluxo}/><section className="op-card op-next-actions"><p className="op-eyebrow">PRÓXIMAS AÇÕES</p><h2>O que precisa de atenção?</h2><button onClick={() => {setAba('fila');setFiltro('ATRASADAS')}}><span>Revisar atrasos</span><b>{painel.atrasadas} →</b></button><button onClick={() => {setAba('gargalos')}}><span>Tratar atividades bloqueadas</span><b>{painel.bloqueadas} →</b></button><button onClick={() => setAba('fila')}><span>Responder às minhas decisões</span><b>{painel.decisoes.length} →</b></button><p className="op-caption">{painel.sem_prazo} sem prazo · {painel.demandas_abertas} demandas sem execução no recorte.</p></section></div>
      </>}
      {aba === 'atendimento' && <>{indicadores([['Entregues',painel.entregues,'Conclusões no período'],['No prazo',numero(painel.no_prazo,'%'),`${painel.amostra_prazo} com prazo informado`],['SLA',numero(painel.sla,'%'),'Duração dentro do SLA cadastrado'],['Tempo de ciclo',numero(painel.ciclo_horas,' h'),'Média entre início e conclusão']])}<div className="op-grid"><GraficoFluxo dados={painel.fluxo}/><GraficoEtapas dados={painel.status}/></div><p className="op-caption">Retrabalho: {numero(painel.retrabalho,'%')} das entregas. SLA exige início e minutos cadastrados. Sem amostra não significa desempenho zero.</p></>}
      {aba === 'gargalos' && <>{indicadores([['Bloqueadas',painel.bloqueadas,'Execuções com bloqueio ativo'],['Dependências',painel.dependencias,'Aguardam resposta ou liberação'],['Sem prazo',painel.sem_prazo,'Precisam de previsão'],['Retrabalho',numero(painel.retrabalho,'%'),'Entregas com retrabalho']])}<div className="op-grid"><Barras titulo="Motivos dos bloqueios" dados={painel.causas}/><Barras titulo="Tempo na carteira" dados={painel.idade}/></div><details className="op-card"><summary>Ver distribuição por setor e etapa</summary><div className="op-grid"><Barras titulo="Volume por setor" dados={painel.gargalos}/><GraficoEtapas dados={painel.status}/></div></details></>}
      {aba === 'fila' && <>
        <section className="op-card"><h2>Decisões aguardando você</h2>{!painel.decisoes.length ? <p className="op-caption">Nenhuma decisão pendente neste recorte.</p> : <ul className="op-decisions">{painel.decisoes.map((d,i) => <li key={`${d.execucao_id}-${i}`}><span><small>{d.etapa}</small>{d.titulo}</span><button onClick={() => abrirExecucao?.(d.execucao_id)}>Analisar</button></li>)}</ul>}</section>
        <section className="op-card"><div className="op-section-heading"><h2>Fila de atenção</h2><div className="op-inline-filters"><label>Buscar atividade<input value={busca} onChange={e => setBusca(e.target.value)} placeholder="Título ou operação"/></label><label>Situação<select value={filtro} onChange={e => setFiltro(e.target.value)}><option value="TODAS">Todas</option><option value="ATRASADAS">Atrasadas</option><option value="BLOQUEADAS">Bloqueadas</option><option value="DEPENDENCIAS">Dependências</option></select></label></div></div><p className="op-caption">Busca nas primeiras 50 atividades prioritárias do setor/operação selecionados. Para a lista completa, abra Operações.</p><div className="op-table-wrap"><table><thead><tr><th>Atividade</th><th>Etapa</th><th>Prazo</th><th>Ação</th></tr></thead><tbody>{fila.map(e => <tr key={e.id}><td><strong>{e.titulo || e.operacao}</strong><small>{e.operacao}</small></td><td><span className={`op-status ${e.bloqueada ? 'op-status-blocked' : ''}`}>{nomeStatus(e.status)}</span></td><td>{e.data_prevista ? new Date(e.data_prevista).toLocaleString('pt-BR') : 'Sem prazo'}</td><td><button onClick={() => abrirExecucao?.(e.id)}>Abrir</button></td></tr>)}</tbody></table>{!fila.length && <p>Nenhuma atividade nesta seleção.</p>}</div></section>
      </>}
      {aba === 'equipe' && <section className="op-card"><h2>{diretor || gestor || usuario.perfil === 'AUDITOR' ? 'Distribuição e entregas' : 'Minhas entregas'}</h2><p className="op-caption">Quantidade de atividades, não capacidade em horas. O filtro de operação considera os responsáveis com atividades nesse recorte.</p><div className="op-table-wrap"><table><thead><tr><th>Pessoa</th><th>Abertas</th><th>Atrasadas</th><th>Entregues</th>{painel.pontuacao_visivel && <><th>Pontuação</th><th>Amostra</th></>}</tr></thead><tbody>{painel.equipe.map(p => <tr key={p.id}><td>{p.nome}</td><td>{p.abertas}</td><td>{p.atrasadas}</td><td>{p.entregues}</td>{painel.pontuacao_visivel && <><td>{numero(p.pontuacao)}</td><td>{p.amostra}</td></>}</tr>)}</tbody></table>{!painel.equipe.length && <p>Nenhuma pessoa com atividades neste recorte.</p>}</div><details><summary>Como interpretar a pontuação</summary><p className="op-caption">Entregas no prazo ÷ entregas com prazo × 100. Sem amostra, sem nota. A pontuação mede pontualidade; avalie também qualidade e contexto.</p></details></section>}
      {aba === 'configuracao' && diretor && <section className="op-card"><h2>Governança da pontuação</h2><p>Esta configuração vale para toda a empresa, independentemente dos filtros.</p><label>Visibilidade<select disabled={salvando} value={painel.modo} onChange={e => void configurar(e.target.value)}><option value="TODOS">Ativa — cada pessoa vê seu escopo</option><option value="GESTAO">Ativa — visível apenas à gestão</option><option value="DESATIVADA">Desativada</option></select></label></section>}
    </>}
    </>}
  </div>
}
