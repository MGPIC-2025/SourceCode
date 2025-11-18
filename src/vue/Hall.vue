<script setup>
import { ref, onMounted, onBeforeUnmount, watch } from 'vue';
import { getAssetUrl } from '../utils/resourceLoader.js';
import './Hall.css';
const emit = defineEmits([
  'startGame',
  'openWarehouse',
  'openTutorial',
  'openEncyclopedia',
  'toggle-music',
]);
const props = defineProps({
  musicOn: {
    type: Boolean,
    default: true,
  },
  paused: {
    type: Boolean,
    default: false,
  },
});
function startGame() {
  emit('startGame');
}
function openWarehouse() {
  emit('openWarehouse');
}
function openTutorial() {
  emit('openTutorial');
}
function openEncyclopedia() {
  const encyclopediaUrl = 'https://mgpic-2025.github.io/CopperPuppetry-Wiki/';
  if (window?.open) {
    window.open(encyclopediaUrl, '_blank', 'noopener');
  } else {
    window.location.href = encyclopediaUrl;
  }
}
const bgStart = ref(getAssetUrl('@assets/frontend_resource/start_game.webp'));
const bgWarehouse = ref(
  getAssetUrl('@assets/frontend_resource/copper_warehouse.webp')
);
const bgWiki = ref(getAssetUrl('@assets/frontend_resource/game_wiki.webp'));
const bgTutorial = ref(getAssetUrl('@assets/frontend_resource/Tutorial.webp'));
const bgHall = ref(
  getAssetUrl('ui/Gemini_Generated_Image_gtrehogtrehogtre (1).png')
);
const imagesLoaded = ref(false);
const audioRef = ref(null);
const musicUrl = getAssetUrl('@assets/frontend_resource/hall.mp3');
onMounted(() => {
  setTimeout(() => {
    imagesLoaded.value = true;
  }, 100);
  if (props.musicOn && !props.paused && audioRef.value) {
    const tryPlay = () => {
      if (audioRef.value.readyState >= 2) {
        audioRef.value
          .play()
          .then(() => {
          })
          .catch(err => {
          });
      } else {
        const onCanPlay = () => {
          audioRef.value
            .play()
            .then(() => {
            })
            .catch(err => {
            });
          audioRef.value.removeEventListener('canplay', onCanPlay);
        };
        audioRef.value.addEventListener('canplay', onCanPlay, { once: true });
      }
    };
    setTimeout(tryPlay, 200);
  }
});
watch(
  () => props.musicOn,
  newVal => {
    if (!audioRef.value) return;
    if (newVal && !props.paused) {
      if (audioRef.value.readyState >= 2) {
        audioRef.value.play().catch(err => {
        });
      } else {
        const playWhenReady = () => {
          audioRef.value.play().catch(err => {
          });
          audioRef.value.removeEventListener('canplay', playWhenReady);
        };
        audioRef.value.addEventListener('canplay', playWhenReady);
      }
    } else {
      audioRef.value.pause();
    }
  }
);
watch(
  () => props.paused,
  newVal => {
    if (!audioRef.value) return;
    if (newVal) {
      audioRef.value.pause();
    } else if (props.musicOn) {
      if (audioRef.value.readyState >= 2) {
        audioRef.value.play().catch(err => {
        });
      } else {
        const playWhenReady = () => {
          audioRef.value.play().catch(err => {
          });
          audioRef.value.removeEventListener('canplay', playWhenReady);
        };
        audioRef.value.addEventListener('canplay', playWhenReady);
      }
    }
  }
);
onBeforeUnmount(() => {
  if (audioRef.value) {
    audioRef.value.pause();
  }
});
</script>
<template>
  <div class="hall-container">
    <div class="hall-bg" :style="{ backgroundImage: `url('${bgHall}')` }"></div>
    <div class="menu" :class="{ 'menu--loaded': imagesLoaded }">
      <button
        class="tile tile--start"
        :style="{ backgroundImage: `url('${bgStart}')` }"
        @click="startGame"
      >
        <div class="tile__mask"></div>
        <div class="tile__caption tile__caption--bottom">
          <div class="tile__title">开始游戏</div>
          <div class="tile__subtitle">Begin Adventure</div>
        </div>
      </button>
      <button
        class="tile tile--warehouse"
        :style="{ backgroundImage: `url('${bgWarehouse}')` }"
        @click="openWarehouse"
      >
        <div class="tile__mask"></div>
        <div class="tile__caption tile__caption--top">
          <div class="tile__title">铜偶仓库</div>
          <div class="tile__subtitle">Character Collection</div>
        </div>
      </button>
      <button
        class="tile tile--wiki"
        :style="{ backgroundImage: `url('${bgWiki}')` }"
        @click="openEncyclopedia"
      >
        <div class="tile__mask"></div>
        <div class="tile__caption tile__caption--bottom">
          <div class="tile__title">游戏百科</div>
          <div class="tile__subtitle">Encyclopedia</div>
        </div>
      </button>
      <button
        class="tile tile--tutorial"
        :style="{ backgroundImage: `url('${bgTutorial}')` }"
        @click="openTutorial"
      >
        <div class="tile__mask"></div>
        <div class="tile__caption tile__caption--top">
          <div class="tile__title">新手教程</div>
          <div class="tile__subtitle">Tutorial</div>
        </div>
      </button>
    </div>
    <audio ref="audioRef" :src="musicUrl" loop preload="auto"></audio>
  </div>
</template>