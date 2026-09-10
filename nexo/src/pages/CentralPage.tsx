import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario, Pagina } from '../types'

type Props = {
  usuario: DadosUsuario
  navegar: (pagina: Pagina) => void
}

type Execucao = {
  id: string
  titulo: string
  status: string
  prioridade: string
  data_prevista: string | null
  percentual_conclusao: number
  responsavel_id: string | null
}

type Demanda = {
  id: string
  titulo: string
  status: string
  prioridade: string
  data_prevista: string | null
  percentual_conclusao: number
  solicitante_id: string
  responsavel_id: string | null
}

function atrasada(data: string | null, status: string) {
  if (!data || ['CONCLUIDA', 'CANCELADA'].includes(status)) return false
  return new Date(data).getTime() < Date.now()
}

function statusLabel(status: string) {
  return status.replaceAll('_', ' ')
}

export default function CentralPage({ usuario, navegar }: Props) {
  const [execucoes, setExecucoes] = useState<Execucao[]>([])
  const [demandas, setDemandas] = useState<Demanda[]>([])
  const [carregando, setCarregando] = useState(true)
  const [mensagem, setMensagem] = useState('')

  useEffect(() => {
    async function carregar() {
      try {
        setCarregando(true)
        setMensagem('')

        const [execDiretas, participacoes, demandasResp, demandasSolic] = await Promise.all([
          supabase
            .from('execucoes')
            .select('id,titulo,status,prioridade,data_prevista,percentual_conclusao,responsavel_id,operacao:operacoes!inner(empresa_id)')
            .eq('operacao.empresa_id', usuario.empresaId)
            .eq('responsavel_id', usuario.pessoaId)
            .neq('status', 'CONCLUIDA')
            .neq('status', 'CANCELADA'),

          supabase
            .from('execucao_participantes')
            .select('execucao:execucoes!inner(id,titulo,status,prioridade,data_prevista,percentual_conclusao,responsavel_id,operacao:operacoes!inner(empresa_id))')
            .eq('pessoa_id', usuario.pessoaId)
            .eq('ativo', true)
            .eq('execucao.operacao.empresa_id', usuario.empresaId),

          supabase
            .from('demandas')
            .select('id,titulo,status,prioridade,data_prevista,percentual_conclusao,solicitante_id,responsavel_id')
            .eq('empresa_id', usuario.empresaId)
            .eq('responsavel_id', usuario.pessoaId)
            .neq('status', 'CONCLUIDA')
            .neq('status', 'CANCELADA'),

          supabase
            .from('demandas')
            .select('id,titulo,status,prioridade,data_prevista,percentual_conclusao,solicitante_id,responsavel_id')
            .eq('empresa_id', usuario.empresaId)
            .eq('solicitante_id', usuario.pessoaId)
            .neq('status', 'CONCLUIDA')
            .neq('status', 'CANCELADA'),
        ])

        for (const resposta of [execDiretas, participacoes, demandasResp, demandasSolic]) {
          if (resposta.error) throw resposta.error
        }

        const mapaExecucoes = new Map<string, Execucao>()
        for (const item of execDiretas.data || []) {
          mapaExecucoes.set(item.id, item as unknown as Execucao)
        }
        for (const item of participacoes.data || []) {
          const execucao = Array.isArray(item.execucao) ? item.execucao[0] : item.execucao
          if (execucao && !['CONCLUIDA', 'CANCELADA'].includes(execucao.status)) {
            mapaExecucoes.set(execucao.id, execucao as unknown as Execucao)
          }
        }

        const mapaDemandas = new Map<string, Demanda>()
        for (const item of [...(demandasResp.data || []), ...(demandasSolic.data || [])]) {
          mapaDemandas.set(item.id, item as Demanda)
        }

        setExecucoes([...mapaExecucoes.values()])
        setDemandas([...mapaDemandas.values()])
      } catch (error: any) {
        console.error(error)
        setMensagem(error?.message || 'Erro ao carregar a central.')
      } finally {
        setCarregando(false)
      }
    }

    carregar()
  }, [usuario.empresaId, usuario.pessoaId])

  const resumo = useMemo(() => {
    const atrasadasExec = execucoes.filter((x) => atrasada(x.data_prevista, x.status)).length
    const atrasadasDem = demandas.filter((x) => atrasada(x.data_prevista, x.status)).length
    const bloqueadas = execucoes.filter((x) => x.status === 'BLOQUEADA').length + demandas.filter((x) => x.status === 'BLOQUEADA').length
    const aguardando = execucoes.filter((x) => x.status.startsWith('AGUARDANDO')).length + demandas.filter((x) => x.status === 'AGUARDANDO').length

    return {
      atividades: execucoes.length,
      demandas: demandas.length,
      atrasadas: atrasadasExec + atrasadasDem,
      bloqueadas,
      aguardando,
    }
  }, [execucoes, demandas])

  const prioridades = useMemo(() => {
    return [...execucoes]
      .sort((a, b) => {
        const peso: Record<string, number> = { CRITICA: 4, ALTA: 3, NORMAL: 2, BAIXA: 1 }
        const atrasoA = atrasada(a.data_prevista, a.status) ? 10 : 0
        const atrasoB = atrasada(b.data_prevista, b.status) ? 10 : 0
        return atrasoB + (peso[b.prioridade] || 0) - (atrasoA + (peso[a.prioridade] || 0))
      })
      .slice(0, 8)
  }, [execucoes])

  if (carregando) {
    return <section className="panel"><div className="empty-state">Carregando sua central...</div></section>
  }

  return (
    <>
      <header className="topbar">
        <div>
          <h1>Minha Central</h1>
          <p>O que exige sua ação agora.</p>
        </div>
        <div className="topbar-user">{usuario.nome}</div>
      </header>

      {mensagem && <div className="system-message">{mensagem}</div>}

      <section className="welcome">
        <h2>Olá, {usuario.nome}</h2>
        <p>Atividades, demandas, atrasos, bloqueios e pendências sob sua responsabilidade ou participação.</p>
      </section>

      <section className="cards-grid nexo-five-cards">
        <div className="status-card"><span className="card-label">Atividades</span><strong className="card-value">{resumo.atividades}</strong></div>
        <div className="status-card"><span className="card-label">Demandas</span><strong className="card-value">{resumo.demandas}</strong></div>
        <div className="status-card"><span className="card-label">Atrasadas</span><strong className="card-value">{resumo.atrasadas}</strong></div>
        <div className="status-card"><span className="card-label">Bloqueadas</span><strong className="card-value">{resumo.bloqueadas}</strong></div>
        <div className="status-card"><span className="card-label">Aguardando</span><strong className="card-value">{resumo.aguardando}</strong></div>
      </section>

      <section className="nexo-quick-actions">
        <button onClick={() => navegar('operacoes')}>Abrir Operações</button>
        <button onClick={() => navegar('demandas')}>Abrir Demandas</button>
        <button onClick={() => navegar('documentos')}>Abrir Documentos</button>
      </section>

      <section className="panel">
        <div className="panel-header"><h3>Prioridades</h3><p>Execuções que merecem atenção primeiro.</p></div>
        {prioridades.length === 0 ? (
          <div className="empty-state">Nenhuma atividade pendente.</div>
        ) : (
          <div className="table-wrapper">
            <table className="operations-table">
              <thead><tr><th>Atividade</th><th>Prioridade</th><th>Status</th><th>Prazo</th><th>Progresso</th></tr></thead>
              <tbody>
                {prioridades.map((item) => (
                  <tr key={item.id}>
                    <td><strong>{item.titulo}</strong>{atrasada(item.data_prevista, item.status) && <div className="nexo-danger-text">ATRASADA</div>}</td>
                    <td>{item.prioridade}</td>
                    <td>{statusLabel(item.status)}</td>
                    <td>{item.data_prevista ? new Date(item.data_prevista).toLocaleString('pt-BR') : 'Sem prazo'}</td>
                    <td>{item.percentual_conclusao}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  )
}
