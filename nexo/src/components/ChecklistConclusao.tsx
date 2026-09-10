import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'

type Props = {
  execucaoId: string
  operacaoId: string
  status: string
  onConcluir: () => Promise<void> | void
}

type Estado = {
  exigeConferencia: boolean
  exigeAprovacao: boolean
  exigeEvidencia: boolean
  bloqueios: number
  dependencias: number
  retrabalhos: number
  conferenciaAprovada: boolean
  aprovacaoAprovada: boolean
  evidencias: number
}

const vazio: Estado = {
  exigeConferencia: false,
  exigeAprovacao: false,
  exigeEvidencia: false,
  bloqueios: 0,
  dependencias: 0,
  retrabalhos: 0,
  conferenciaAprovada: false,
  aprovacaoAprovada: false,
  evidencias: 0,
}

export default function ChecklistConclusao({
  execucaoId,
  operacaoId,
  status,
  onConcluir,
}: Props) {
  const [estado, setEstado] = useState<Estado>(vazio)
  const [carregando, setCarregando] = useState(true)
  const [erro, setErro] = useState('')

  useEffect(() => {
    let ativo = true

    async function carregar() {
      try {
        setCarregando(true)
        setErro('')

        const [op, b, d, r, c, a, e] = await Promise.all([
          supabase
            .from('operacoes')
            .select('exige_conferencia,exige_aprovacao,exige_evidencia')
            .eq('id', operacaoId)
            .single(),
          supabase
            .from('bloqueios')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .eq('ativo', true),
          supabase
            .from('dependencias')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .eq('ativo', true),
          supabase
            .from('retrabalhos')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .in('status', ['PENDENTE', 'EM_CORRECAO']),
          supabase
            .from('conferencias')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .eq('resultado', 'APROVADA'),
          supabase
            .from('aprovacoes')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId)
            .eq('status', 'APROVADA'),
          supabase
            .from('evidencias')
            .select('id', { count: 'exact', head: true })
            .eq('execucao_id', execucaoId),
        ])

        for (const resp of [op, b, d, r, c, a, e]) {
          if (resp.error) throw resp.error
        }

        if (!ativo) return

        setEstado({
          exigeConferencia: !!op.data?.exige_conferencia,
          exigeAprovacao: !!op.data?.exige_aprovacao,
          exigeEvidencia: !!op.data?.exige_evidencia,
          bloqueios: b.count || 0,
          dependencias: d.count || 0,
          retrabalhos: r.count || 0,
          conferenciaAprovada: (c.count || 0) > 0,
          aprovacaoAprovada: (a.count || 0) > 0,
          evidencias: e.count || 0,
        })
      } catch (error: any) {
        if (ativo) setErro(error?.message || 'Não foi possível validar a conclusão.')
      } finally {
        if (ativo) setCarregando(false)
      }
    }

    carregar()
    return () => {
      ativo = false
    }
  }, [execucaoId, operacaoId, status])

  const itens = useMemo(() => [
    {
      label: 'Sem bloqueio ativo',
      ok: estado.bloqueios === 0,
      detalhe: estado.bloqueios ? `${estado.bloqueios} bloqueio(s) aberto(s)` : 'OK',
    },
    {
      label: 'Sem dependência ativa',
      ok: estado.dependencias === 0,
      detalhe: estado.dependencias ? `${estado.dependencias} dependência(s) aberta(s)` : 'OK',
    },
    {
      label: 'Sem retrabalho pendente',
      ok: estado.retrabalhos === 0,
      detalhe: estado.retrabalhos ? `${estado.retrabalhos} retrabalho(s) pendente(s)` : 'OK',
    },
    {
      label: 'Conferência',
      ok: !estado.exigeConferencia || estado.conferenciaAprovada,
      detalhe: estado.exigeConferencia
        ? estado.conferenciaAprovada ? 'Aprovada' : 'Obrigatória e pendente'
        : 'Não exigida',
    },
    {
      label: 'Aprovação',
      ok: !estado.exigeAprovacao || estado.aprovacaoAprovada,
      detalhe: estado.exigeAprovacao
        ? estado.aprovacaoAprovada ? 'Aprovada' : 'Obrigatória e pendente'
        : 'Não exigida',
    },
    {
      label: 'Evidência',
      ok: !estado.exigeEvidencia || estado.evidencias > 0,
      detalhe: estado.exigeEvidencia
        ? estado.evidencias > 0 ? `${estado.evidencias} registrada(s)` : 'Obrigatória e ausente'
        : `${estado.evidencias} registrada(s)`,
    },
  ], [estado])

  const pronta = itens.every((x) => x.ok)
  const encerrada = ['CONCLUIDA', 'CANCELADA'].includes(status)

  return (
    <div className="nexo-conclusion-check">
      <div className="nexo-conclusion-title">
        <div>
          <h4>Prontidão para concluir</h4>
          <p>
            {carregando
              ? 'Validando requisitos...'
              : pronta
                ? 'Todos os requisitos foram atendidos.'
                : 'Existem pendências que impedem a conclusão.'}
          </p>
        </div>
        {!carregando && (
          <span className={pronta ? 'nexo-ready-badge ready' : 'nexo-ready-badge pending'}>
            {pronta ? 'PRONTA' : 'PENDENTE'}
          </span>
        )}
      </div>

      {erro && <div className="system-message">{erro}</div>}

      <div className="nexo-check-list">
        {itens.map((item) => (
          <div className={item.ok ? 'nexo-check-item ok' : 'nexo-check-item pendente'} key={item.label}>
            <span>{item.ok ? '✓' : '!'}</span>
            <div>
              <strong>{item.label}</strong>
              <small>{item.detalhe}</small>
            </div>
          </div>
        ))}
      </div>

      <button
        className="primary-button"
        onClick={onConcluir}
        disabled={carregando || !pronta || encerrada}
      >
        {encerrada ? 'Execução encerrada' : pronta ? 'Concluir execução' : 'Resolva as pendências para concluir'}
      </button>
    </div>
  )
}
