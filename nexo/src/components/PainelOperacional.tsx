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

export default function PainelOperacional({ usuario, navegar, abrirExecucao, foco = 'painel' }: Props) {
  const [dias, setDias] = useState(30)
  const [painel, setPainel] = useState<Painel | null>(null)
  const [erro, setErro] = useState('')
  const [revisao, setRevisao] = useState(0)
  const [salvando, setSalvando] = useState(false)
  const [filtro, setFiltro] = useState('TODAS')
  const diretor = ['ADMIN', 'DIRETORIA'].includes(usuario.perfil)
  const gestor = ['LIDER', 'GESTOR', 'GERENTE'].includes(usuario.perfil)
  const escopo = diretor || usuario.perfil === 'AUDITOR' ? 'Toda a empresa' : gestor ? 'Sua equipe' : 'Suas atividades'
  useEffect(() => {
    let cancelado = false
    setPainel(null); setErro('')
    supabase.rpc('nexo_painel_operacional', { p_dias: dias }).then(({ data, error }) => {
      if (cancelado) return
      if (error) setErro('Não foi possível carregar o painel. Verifique a conexão e se o pacote operacional foi aplicado no Supabase.')
      else setPainel(data as Painel)
    }, () => { if (!cancelado) setErro('Falha de conexão. Tente atualizar.') })
    return () => { cancelado = true }
  }, [dias, revisao, usuario.pessoaId, usuario.perfil])
  async function configurar(modo: string) {
    setSalvando(true); setErro('')
    try {
      const { error } = await supabase.rpc('nexo_configurar_pontuacao', { p_modo: modo })
      if (error) throw error
      setRevisao(r => r + 1)
    } catch { setErro('Não foi possível salvar a configuração.') }
    finally { setSalvando(false) }
  }
  const fila = painel?.fila.filter(e => filtro === 'TODAS' || (filtro === 'ATRASADAS' ? e.data_prevista && new Date(e.data_prevista) < new Date(painel.gerado_em) : filtro === 'BLOQUEADAS' ? e.bloqueada : e.dependente)) || []
  return <main className="op-panel">
    <header className="op-header"><div><p className="op-eyebrow">NEXO / {escopo}</p><h1>{foco === 'equipe' ? 'Equipe e capacidade' : diretor ? 'Visão executiva' : gestor ? 'Gestão da equipe' : 'Minha operação'}</h1><p>Prioridades claras. Entregas acompanhadas. Decisões com contexto.</p></div><div className="op-actions"><label>Período de entregas<select value={dias} onChange={e => setDias(Number(e.target.value))}><option value={7}>Últimos 7 dias</option><option value={30}>Últimos 30 dias</option><option value={90}>Últimos 90 dias</option></select></label><button onClick={() => setRevisao(r => r + 1)}>Atualizar</button></div></header>
    {erro && <p className="op-error" role="alert">{erro}</p>}
    {!painel ? !erro && <p role="status">Carregando indicadores do seu escopo…</p> : <>
      <p className="op-caption">Carteira = situação atual. Entregas e qualidade = período selecionado. Atualizado em {new Date(painel.gerado_em).toLocaleString('pt-BR')}.</p>
      {foco !== 'equipe' && <>
      <div className="op-kpis">{[
        ['Carteira aberta', painel.abertas, 'Execuções em andamento'], ['Atrasadas', painel.atrasadas, 'Prazo vencido, ainda abertas'],
        ['Entregues', painel.entregues, 'Concluídas no período'], ['No prazo', numero(painel.no_prazo, '%'), `${painel.amostra_prazo} entregas com prazo informado`],
        ['SLA de execução', numero(painel.sla, '%'), 'Duração dentro do SLA cadastrado'], ['Sem prazo', painel.sem_prazo, 'Abertas sem data prevista'], ['Aguardando dependências', painel.dependencias, 'Execuções com dependência ativa'], ['Tempo de ciclo', numero(painel.ciclo_horas, ' h'), 'Média entre início e conclusão'], ['Retrabalho', numero(painel.retrabalho, '%'), 'Entregas que tiveram retrabalho'],
      ].map(([t, v, d]) => <section key={String(t)} className="op-kpi"><span>{t}</span><strong>{v}</strong><small>{d}</small></section>)}</div>
      <section className="op-card op-insights"><h2>Onde agir agora</h2><div className="op-insight-grid"><p><b>{painel.bloqueadas}</b> execuções bloqueadas. Identifique a causa e o responsável pela liberação.</p><p><b>{painel.dependencias}</b> aguardam dependências. Atualize a próxima ação e a previsão de retorno.</p><p><b>{painel.sem_prazo}</b> estão sem prazo. Defina a data para medir atendimento.</p><p><b>{painel.demandas_abertas}</b> demandas aguardam tratamento, sem execução vinculada. {navegar && <button onClick={() => navegar('demandas')}>Abrir demandas</button>}</p></div></section>
      <div className="op-grid"><Barras titulo="Atendimento diário" dados={painel.fluxo} fluxo /><Barras titulo="Carteira por etapa" dados={painel.status} /><Barras titulo="Volume por setor" dados={painel.gargalos} /><Barras titulo="Tempo na carteira" dados={painel.idade} /><Barras titulo="Principais motivos de bloqueio" dados={painel.causas} /><section className="op-card"><h2>Decisões aguardando você</h2>{!painel.decisoes.length ? <p>Nenhuma conferência ou aprovação pendente.</p> : <ul className="op-decisions">{painel.decisoes.map((d, i) => <li key={`${d.execucao_id}-${i}`}><span><small>{d.etapa}</small>{d.titulo}</span><button onClick={() => abrirExecucao?.(d.execucao_id)}>Analisar</button></li>)}</ul>}</section></div>
      <section className="op-card"><div className="op-section-heading"><h2>Fila de atenção</h2><label>Exibir<select value={filtro} onChange={e => setFiltro(e.target.value)}><option value="TODAS">Todas</option><option value="ATRASADAS">Atrasadas</option><option value="BLOQUEADAS">Bloqueadas</option><option value="DEPENDENCIAS">Dependências</option></select></label></div><p className="op-caption">Até 50 atividades prioritárias: atrasos, bloqueios e prazos mais próximos. Bloqueios e dependências podem coexistir.</p><div className="op-table-wrap"><table><thead><tr><th>Atividade</th><th>Etapa</th><th>Prazo</th><th>Ação</th></tr></thead><tbody>{fila.map(e => <tr key={e.id}><td><strong>{e.titulo || e.operacao}</strong><small>{e.operacao}{e.bloqueada ? ' · Bloqueada' : ''}{e.dependente ? ' · Dependência' : ''}</small></td><td>{nomeStatus(e.status)}</td><td>{e.data_prevista ? new Date(e.data_prevista).toLocaleString('pt-BR') : 'Sem prazo'}</td><td><button onClick={() => abrirExecucao?.(e.id)}>Abrir</button></td></tr>)}</tbody></table>{!fila.length && <p>Nenhuma atividade nesta seleção.</p>}</div></section>
      </>}
      <section className="op-card"><h2>{diretor || gestor || usuario.perfil === 'AUDITOR' ? 'Equipe: distribuição e entregas' : 'Minhas entregas'}</h2><p className="op-caption">Carteira representa quantidade, não horas de capacidade. Pontuação de pontualidade = entregas no prazo ÷ entregas com prazo × 100. Sem amostra, sem nota. Não mede desempenho individual completo.</p><div className="op-table-wrap"><table><thead><tr><th>Pessoa</th><th>Abertas</th><th>Atrasadas</th><th>Entregues</th>{painel.pontuacao_visivel && <><th>Pontuação</th><th>Amostra</th></>}</tr></thead><tbody>{painel.equipe.map(p => <tr key={p.id}><td>{p.nome}</td><td>{p.abertas}</td><td>{p.atrasadas}</td><td>{p.entregues}</td>{painel.pontuacao_visivel && <><td>{numero(p.pontuacao)}</td><td>{p.amostra}</td></>}</tr>)}</tbody></table></div></section>
      {diretor && <section className="op-card"><h2>Governança da pontuação</h2><p>A configuração vale para toda a empresa e fica registrada no histórico.</p><label>Visibilidade<select disabled={salvando} value={painel.modo} onChange={e => void configurar(e.target.value)}><option value="TODOS">Ativa — cada pessoa vê somente seu escopo</option><option value="GESTAO">Ativa — visível apenas à gestão</option><option value="DESATIVADA">Desativada — nenhuma nota é calculada</option></select></label></section>}
    </>}
  </main>
}
