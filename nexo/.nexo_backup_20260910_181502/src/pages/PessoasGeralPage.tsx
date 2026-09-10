import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'
import { scorePessoa, type BloqueioGestao, type CargaGestao, type DependenciaGestao, type ExecucaoGestao, type RetrabalhoGestao } from '../lib/gestao'

type Props = { usuario: DadosUsuario }
type Pessoa = { id: string; nome: string; email: string | null; setor_id: string | null; setor?: { nome: string } | null; cargo?: { nome: string } | null }
type Demanda = { id: string; responsavel_id: string | null; status: string; data_prevista: string | null }
type Resp = { pessoa_id: string; operacao_id: string; papel: string; ativo: boolean }

function normalizarRelacao<T>(valor: T | T[] | null | undefined): T | null { if (!valor) return null; return Array.isArray(valor) ? valor[0] || null : valor }

export default function PessoasGeralPage({ usuario }: Props) {
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [execucoes, setExecucoes] = useState<ExecucaoGestao[]>([])
  const [demandas, setDemandas] = useState<Demanda[]>([])
  const [carga, setCarga] = useState<CargaGestao[]>([])
  const [responsabilidades, setResponsabilidades] = useState<Resp[]>([])
  const [retrabalhos, setRetrabalhos] = useState<RetrabalhoGestao[]>([])
  const [bloqueios, setBloqueios] = useState<BloqueioGestao[]>([])
  const [dependencias, setDependencias] = useState<DependenciaGestao[]>([])
  const [mensagem, setMensagem] = useState('')
  const [selecionada, setSelecionada] = useState<string>('')

  useEffect(() => {
    async function carregar() {
      try {
        const [p, e, d, c, r, rt, b, dp] = await Promise.all([
          supabase.from('pessoas').select('id,nome,email,setor_id,setor:setores(nome),cargo:cargos(nome)').eq('empresa_id', usuario.empresaId).eq('ativo', true).order('nome'),
          supabase.from('execucoes').select('id,titulo,status,prioridade,data_prevista,data_inicio,data_conclusao,responsavel_id,operacao_id,percentual_conclusao'),
          supabase.from('demandas').select('id,responsavel_id,status,data_prevista').eq('empresa_id', usuario.empresaId),
          supabase.from('carga_trabalho').select('pessoa_id,tempo_estimado_minutos,percentual_carga'),
          supabase.from('operacao_responsaveis').select('pessoa_id,operacao_id,papel,ativo').eq('ativo', true),
          supabase.from('retrabalhos').select('id,execucao_id,pessoa_origem_id,responsavel_correcao_id,status'),
          supabase.from('bloqueios').select('id,execucao_id,ativo,motivo,iniciado_em,finalizado_em'),
          supabase.from('dependencias').select('id,execucao_id,ativo,tipo_dependencia,motivo,impacto,entidade_externa,previsao_retorno,proxima_acao,iniciado_em,finalizado_em'),
        ])
        for (const x of [p, e, d, c, r, rt, b, dp]) if (x.error) throw x.error
        setPessoas((p.data || []).map((item: any) => ({ ...item, setor: normalizarRelacao(item.setor), cargo: normalizarRelacao(item.cargo) })) as Pessoa[])
        setExecucoes((e.data || []) as unknown as ExecucaoGestao[])
        setDemandas((d.data || []) as Demanda[])
        setCarga((c.data || []) as unknown as CargaGestao[])
        setResponsabilidades((r.data || []) as Resp[])
        setRetrabalhos((rt.data || []) as unknown as RetrabalhoGestao[])
        setBloqueios((b.data || []) as unknown as BloqueioGestao[])
        setDependencias((dp.data || []) as unknown as DependenciaGestao[])
      } catch (error: any) {
        console.error(error); setMensagem(error?.message || 'Erro ao carregar pessoas.')
      }
    }
    carregar()
  }, [usuario.empresaId])

  const linhas = useMemo(() => pessoas.map((pessoa) => {
    const dem = demandas.filter((x) => x.responsavel_id === pessoa.id && !['CONCLUIDA', 'CANCELADA'].includes(x.status))
    const respons = responsabilidades.filter((x) => x.pessoa_id === pessoa.id)
    return { ...pessoa, demandas: dem.length, responsabilidades: respons.length, ...scorePessoa({ pessoaId: pessoa.id, execucoes, retrabalhos, bloqueios, dependencias, carga }) }
  }).sort((a, b) => b.score - a.score), [pessoas, demandas, responsabilidades, execucoes, retrabalhos, bloqueios, dependencias, carga])

  const atual = linhas.find((x) => x.id === selecionada)

  return (
    <>
      <header className="topbar"><div><h1>Pessoas</h1><p>Desempenho, carga, responsabilidades e contexto operacional.</p></div><div className="topbar-user">{usuario.nome}</div></header>
      {mensagem && <div className="system-message">{mensagem}</div>}
      <section className="panel">
        <div className="panel-header"><h3>Equipe</h3><p>A pontuação considera resultado e contexto; dependências externas não são tratadas como falha individual.</p></div>
        <div className="table-wrapper"><table className="operations-table"><thead><tr><th>Pessoa</th><th>Setor / Cargo</th><th>Score</th><th>Carga</th><th>Responsabilidades</th><th>Abertas</th><th>Atrasadas</th><th>Demandas</th><th></th></tr></thead><tbody>{linhas.map((item) => <tr key={item.id}><td><strong>{item.nome}</strong><div className="nexo-muted">{item.email || ''}</div></td><td>{item.setor?.nome || '-'} / {item.cargo?.nome || '-'}</td><td><span className={`nexo-score-pill score-${item.classificacao.nivel}`}>{item.classificacao.emoji} {item.score}</span></td><td>{item.cargaTotal}%</td><td>{item.responsabilidades}</td><td>{item.abertas}</td><td>{item.atrasadas}</td><td>{item.demandas}</td><td><button className="table-action-button" onClick={() => setSelecionada(item.id)}>Analisar</button></td></tr>)}</tbody></table></div>
      </section>

      {atual && <section className="panel"><div className="panel-header"><h3>{atual.nome}</h3><p>{atual.classificacao.emoji} Score {atual.score} — {atual.classificacao.label}</p></div><div className="nexo-person-detail"><div className="nexo-score-big"><strong>{atual.score}</strong><span>Score NEXO</span></div><div className="nexo-metric-list"><div><span>Prazo</span><strong>{atual.prazo}/25</strong></div><div><span>Qualidade</span><strong>{atual.qualidade}/20</strong></div><div><span>SLA</span><strong>{atual.sla}/15</strong></div><div><span>Produtividade</span><strong>{atual.produtividade}/15</strong></div><div><span>Carga equilibrada</span><strong>{atual.cargaScore}/10</strong></div><div><span>Regularidade</span><strong>{atual.regularidade}/5</strong></div></div><div className="nexo-insight-box"><h4>Leitura do desempenho</h4><p><strong>Principal impacto:</strong> {atual.principalImpacto}</p><p>{atual.cargaTotal > 100 ? 'A pessoa está acima da capacidade planejada. Antes de interpretar atrasos como baixa performance, redistribua carga.' : atual.atrasosComDependencia > 0 ? 'Existem atrasos ligados a dependências externas; eles devem ser tratados como problema de fluxo, não como falha individual.' : atual.score >= 80 ? 'Desempenho consistente no período analisado.' : 'Existem sinais que merecem acompanhamento do líder.'}</p><p><b>Atrasos externos:</b> {atual.atrasosComDependencia} • <b>Retrabalho de origem:</b> {atual.retrabalhoOrigem} • <b>Bloqueios ativos:</b> {atual.bloqueiosAtivos}</p></div></div></section>}
    </>
  )
}
