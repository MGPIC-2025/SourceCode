<script setup>
import { computed, onMounted, ref } from 'vue';
import { eventloop } from '../../glue.js';
import { getAssetUrl } from '../../utils/resourceLoader.js';
import './TurnSystem.css';
const props = defineProps({
  currentCopperId: {
    type: Number,
    default: null,
  },
  copperList: {
    type: Array,
    default: () => [],
  },
  roundNumber: {
    type: Number,
    default: 1,
  },
  isEnemyMoving: {
    type: Boolean,
    default: false,
  },
});
const emit = defineEmits(['nextCopper', 'endRound', 'selectCopper']);
const turnSystemRef = ref(null);
const choiceImgSrc = getAssetUrl('ui/choice.png');
const choiceActiveImgSrc = getAssetUrl('ui/choice-active.png');
const ribbonLeftSrc = `url('${getAssetUrl('ui/ribbon-left.png')}')`;
const ribbonMiddleSrc = `url('${getAssetUrl('ui/ribbon-middle.png')}')`;
const ribbonRightSrc = `url('${getAssetUrl('ui/ribbon-right.png')}')`;
const panelSrc = `url('${getAssetUrl('ui/panel.png')}')`;
const round1Src = `url('${getAssetUrl('ui/round1.png')}')`;
const currentCupperSrc = `url('${getAssetUrl('ui/currentcupper.png')}')`;
const btnSrc = `url('${getAssetUrl('ui/btn.png')}')`;
const currentCopperInfo = computed(() => {
  if (!props.currentCopperId) return null;
  const copper = props.copperList.find(c => c.id === props.currentCopperId);
  if (!copper) return null;
  return {
    id: copper.id,
    name: copper.name || `铜偶 #${copper.id}`,
    level: copper.level ?? 0,
    isSummon: copper.type === 'summon',
  };
});
function handleNextCopper() {
  emit('nextCopper');
}
async function handleEndRound() {
  const message = JSON.stringify({ type: 'on_game_round_pass' });
  eventloop(message);
  emit('endRound');
}
function handleSelectCopper(id) {
  emit('selectCopper', id);
}
onMounted(async () => {
  if (!turnSystemRef.value) return;
  function loadImage(src) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = err => {
        reject(err);
      };
      img.src = src;
    });
  }
  function setCssVar(name, value) {
    if (turnSystemRef.value) {
      turnSystemRef.value.style.setProperty(name, String(value));
    }
  }
  try {
    const [panelImg, btnImg, currentImg] = await Promise.all([
      loadImage(getAssetUrl('ui/panel.png')),
      loadImage(getAssetUrl('ui/btn.png')),
      loadImage(getAssetUrl('ui/currentcupper.png')),
    ]);
    const panelSlice = Math.max(4, Math.round(panelImg.naturalHeight / 4));
    const btnSlice = Math.max(3, Math.round(btnImg.naturalHeight / 3));
    const currentSlice = Math.max(3, Math.round(currentImg.naturalHeight / 4));
    setCssVar('--panel-slice', panelSlice);
    setCssVar('--btn-slice', btnSlice);
    setCssVar('--current-slice', currentSlice);
    setTimeout(() => {
      const computed = getComputedStyle(turnSystemRef.value);
    }, 100);
  } catch (err) {
    setCssVar('--panel-slice', '8');
    setCssVar('--btn-slice', '11');
    setCssVar('--current-slice', '8');
  }
});
</script>
<template>
  <div ref="turnSystemRef" class="turn-system">
    <div class="ribbon" aria-hidden="true">
      <div class="ribbon-cap left"></div>
      <div class="ribbon-fill">CONTROL</div>
      <div class="ribbon-cap right"></div>
    </div>
    <div class="panel">
      <div class="panel-inner">
        <section class="section section-header">
          <div
            class="round-header"
            role="img"
            :aria-label="`Round ${roundNumber}`"
          >
            Round {{ roundNumber }}
          </div>
        </section>
        <section class="section section-body">
          <div class="current-doll" role="status" aria-live="polite">
            <span>
              {{
                currentCopperInfo
                  ? `当前铜偶：${currentCopperInfo.name || `铜偶 #${currentCopperId}`}`
                  : '当前铜偶：—'
              }}
            </span>
            <span v-if="currentCopperInfo && !currentCopperInfo.isSummon">
              （Lv.{{ currentCopperInfo.level ?? 0 }}）
            </span>
          </div>
        </section>
        <section
          class="section section-choices"
          role="group"
          aria-label="Character Queue"
        >
          <button
            v-for="copper in copperList"
            :key="copper.id"
            class="choice"
            type="button"
            :aria-pressed="String(copper.id === currentCopperId)"
            :data-copper-id="copper.id"
            :title="copper.name || `铜偶 #${copper.id}`"
            @click="handleSelectCopper(copper.id)"
          >
            <img
              :alt="copper.name || `Character ${copper.id}`"
              :src="
                copper.id === currentCopperId
                  ? choiceActiveImgSrc
                  : choiceImgSrc
              "
              :data-default-src="choiceImgSrc"
              :data-selected-src="choiceActiveImgSrc"
            />
          </button>
        </section>
      </div>
    </div>
    <div class="actions">
      <button
        class="btn btn-primary"
        @click="handleNextCopper"
        :disabled="!currentCopperId || isEnemyMoving"
      >
        下一个
      </button>
      <button
        class="btn btn-secondary"
        @click="handleEndRound"
        :disabled="isEnemyMoving"
      >
        结束回合
      </button>
    </div>
  </div>
</template>
<style scoped>
.ribbon-cap.left {
  background-image: v-bind(ribbonLeftSrc);
}
.ribbon-cap.right {
  background-image: v-bind(ribbonRightSrc);
}
.ribbon-fill {
  background-image: v-bind(ribbonMiddleSrc);
}
.panel {
  border-image-source: v-bind(panelSrc);
}
.round-header {
  border-image-source: v-bind(round1Src);
}
.current-doll {
  border-image-source: v-bind(currentCupperSrc);
}
.btn {
  border-image-source: v-bind(btnSrc);
}
</style>